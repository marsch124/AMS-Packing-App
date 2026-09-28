import Foundation
import PackingCore

// A trip's packing list as an Excel file — the web app's "Excel" button, and its
// js/xlsx.js ported: just enough Office Open XML for a sheet with a bold,
// coloured header row that stays in place, zipped without compression. No
// library, nothing online.

/// One cell: words, a number, or nothing.
public enum XlsxCell: Equatable, Sendable {
    case text(String)
    case number(Double)
    case empty
}

public struct XlsxColumn: Equatable, Sendable {
    public var header: String
    public var width: Double
    public init(_ header: String, width: Double = 14) { self.header = header; self.width = width }
}

public struct XlsxSheet: Equatable, Sendable {
    public var name: String
    public var columns: [XlsxColumn]
    public var rows: [[XlsxCell]]
    public init(name: String, columns: [XlsxColumn], rows: [[XlsxCell]]) {
        self.name = name; self.columns = columns; self.rows = rows
    }
}

public enum Xlsx {
    public static let mime = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

    // ---------- a minimal ZIP ("store", no compression) ----------
    static let crcTable: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = c & 1 == 1 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    public static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for b in bytes { c = (c >> 8) ^ crcTable[Int((c ^ UInt32(b)) & 0xFF)] }
        return c ^ 0xFFFF_FFFF
    }

    static func zipStore(_ files: [(name: String, data: [UInt8])]) -> Data {
        func u16(_ n: Int) -> [UInt8] { [UInt8(n & 0xFF), UInt8((n >> 8) & 0xFF)] }
        func u32(_ n: UInt32) -> [UInt8] { [UInt8(n & 0xFF), UInt8((n >> 8) & 0xFF), UInt8((n >> 16) & 0xFF), UInt8((n >> 24) & 0xFF)] }
        var out: [UInt8] = []
        var central: [UInt8] = []
        for f in files {
            let name = Array(f.name.utf8)
            let crc = crc32(f.data), size = UInt32(f.data.count), at = UInt32(out.count)
            out += u32(0x0403_4B50) + u16(20) + u16(0) + u16(0) + u16(0) + u16(0) + u32(crc) + u32(size) + u32(size)
                + u16(name.count) + u16(0) + name + f.data
            central += u32(0x0201_4B50) + u16(20) + u16(20) + u16(0) + u16(0) + u16(0) + u16(0) + u32(crc) + u32(size)
                + u32(size) + u16(name.count) + u16(0) + u16(0) + u16(0) + u16(0) + u32(0) + u32(at) + name
        }
        let start = UInt32(out.count)
        out += central
        out += u32(0x0605_4B50) + u16(0) + u16(0) + u16(files.count) + u16(files.count)
            + u32(UInt32(central.count)) + u32(start) + u16(0)
        return Data(out)
    }

    // ---------- Office Open XML ----------
    static func xesc(_ s: String) -> String {
        var o = ""
        for ch in s {
            switch ch {
            case "&": o += "&amp;"
            case "<": o += "&lt;"
            case ">": o += "&gt;"
            case "\"": o += "&quot;"
            case "'": o += "&apos;"
            default: o.append(ch)
            }
        }
        return o
    }

    /// 0 → A, 25 → Z, 26 → AA.
    static func colLetter(_ i: Int) -> String {
        var s = "", n = i + 1
        while n > 0 {
            let m = (n - 1) % 26
            s = String(UnicodeScalar(UInt8(65 + m))) + s
            n = (n - 1) / 26
        }
        return s
    }

    static func number(_ v: Double) -> String {
        v.rounded() == v && abs(v) < 1e15 ? String(Int(v)) : String(v)
    }

    static func sheetXml(_ sheet: XlsxSheet) -> String {
        let cols = sheet.columns.isEmpty ? "" : "<cols>" + sheet.columns.enumerated().map { i, c in
            "<col min=\"\(i + 1)\" max=\"\(i + 1)\" width=\"\(number(c.width))\" customWidth=\"1\"/>"
        }.joined() + "</cols>"
        let header = "<row r=\"1\">" + sheet.columns.enumerated().map { i, c in
            "<c r=\"\(colLetter(i))1\" s=\"1\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(xesc(c.header))</t></is></c>"
        }.joined() + "</row>"
        let body = sheet.rows.enumerated().map { r, row -> String in
            let rn = r + 2
            return "<row r=\"\(rn)\">" + row.enumerated().map { i, v -> String in
                let ref = "\(colLetter(i))\(rn)"
                switch v {
                case .empty: return ""
                case .number(let n) where n.isFinite: return "<c r=\"\(ref)\"><v>\(number(n))</v></c>"
                case .number: return ""
                case .text(let t) where t.isEmpty: return ""
                case .text(let t): return "<c r=\"\(ref)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(xesc(t))</t></is></c>"
                }
            }.joined() + "</row>"
        }.joined()
        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
            + "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">"
            + "<sheetViews><sheetView workbookViewId=\"0\"><pane ySplit=\"1\" topLeftCell=\"A2\" activePane=\"bottomLeft\" state=\"frozen\"/></sheetView></sheetViews>"
            + "<sheetFormatPr defaultRowHeight=\"15\"/>\(cols)<sheetData>\(header)\(body)</sheetData></worksheet>"
    }

    /// Two styles: 0 = body (wrapped, top), 1 = header (bold white on the web app's teal).
    static let stylesXml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        + "<styleSheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">"
        + "<fonts count=\"2\"><font><sz val=\"11\"/><name val=\"Calibri\"/></font><font><b/><sz val=\"11\"/><color rgb=\"FFFFFFFF\"/><name val=\"Calibri\"/></font></fonts>"
        + "<fills count=\"3\"><fill><patternFill patternType=\"none\"/></fill><fill><patternFill patternType=\"gray125\"/></fill><fill><patternFill patternType=\"solid\"><fgColor rgb=\"FF127A8A\"/></patternFill></fill></fills>"
        + "<borders count=\"1\"><border/></borders>"
        + "<cellStyleXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellStyleXfs>"
        + "<cellXfs count=\"2\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\" applyAlignment=\"1\"><alignment vertical=\"top\" wrapText=\"1\"/></xf>"
        + "<xf numFmtId=\"0\" fontId=\"1\" fillId=\"2\" borderId=\"0\" xfId=\"0\" applyFont=\"1\" applyFill=\"1\" applyAlignment=\"1\"><alignment vertical=\"center\"/></xf></cellXfs>"
        + "<cellStyles count=\"1\"><cellStyle name=\"Normal\" xfId=\"0\" builtinId=\"0\"/></cellStyles></styleSheet>"

    /// An .xlsx file from its sheets.
    public static func workbook(_ sheets: [XlsxSheet]) -> Data {
        let types = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
            + "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
            + "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
            + "<Default Extension=\"xml\" ContentType=\"application/xml\"/>"
            + "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>"
            + "<Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>"
            + sheets.indices.map { "<Override PartName=\"/xl/worksheets/sheet\($0 + 1).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" }.joined()
            + "</Types>"
        let rootRels = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
            + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
            + "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>"
        let wbRels = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
            + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
            + sheets.indices.map { "<Relationship Id=\"rId\($0 + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\($0 + 1).xml\"/>" }.joined()
            + "<Relationship Id=\"rId\(sheets.count + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/></Relationships>"
        let book = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
            + "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">"
            + "<sheets>" + sheets.enumerated().map { i, s in "<sheet name=\"\(xesc(sheetName(s.name)))\" sheetId=\"\(i + 1)\" r:id=\"rId\(i + 1)\"/>" }.joined()
            + "</sheets></workbook>"
        var files: [(name: String, data: [UInt8])] = [
            ("[Content_Types].xml", Array(types.utf8)),
            ("_rels/.rels", Array(rootRels.utf8)),
            ("xl/workbook.xml", Array(book.utf8)),
            ("xl/_rels/workbook.xml.rels", Array(wbRels.utf8)),
            ("xl/styles.xml", Array(stylesXml.utf8)),
        ]
        for (i, s) in sheets.enumerated() { files.append(("xl/worksheets/sheet\(i + 1).xml", Array(sheetXml(s).utf8))) }
        return zipStore(files)
    }

    /// Excel's rule for a sheet's name: at most 31 characters, none of [ ] : * ? / \.
    public static func sheetName(_ name: String) -> String {
        let cleaned = String(name.map { "[]:*?/\\".contains($0) ? " " : $0 })
        let s = String(jsTrim(cleaned).prefix(31))
        return s.isEmpty ? "Trip" : s
    }
}

extension Library {
    /// A trip's packing list as an Excel file, in the order of the trip screen: by
    /// When, then by bag. How many is what he packs — per-night things times the
    /// nights, capped when there is laundry — and a line set aside says so.
    public func tripWorkbook(tripId: String) -> (fileName: String, data: Data)? {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return nil }
        let nights = qtyNights(trip)
        var rows: [[XlsxCell]] = []
        for g in entriesByPhase(trip.entries) {
            for bag in groupByContainer(g.entries) {
                for e in bag.entries {
                    let packed: String = isSetAside(e) ? "set aside" : (e.checked ? "yes" : "")
                    rows.append([.text(g.phase.label), .text(jsTrim(e.storage)), .text(e.container), .text(e.name),
                                 .number(effectiveQty(e, nights)), .text(packed), .text(e.note)])
                }
            }
        }
        // His words (test D.23, 2026-09-28): where it comes FROM at home, and the bag it goes INTO —
        // the same two words as the trip screen's sorting.
        let columns = [XlsxColumn("When", width: 22), XlsxColumn("From where", width: 20), XlsxColumn("Into", width: 20),
                       XlsxColumn("Thing", width: 30),
                       XlsxColumn("How many", width: 10), XlsxColumn("Packed", width: 10), XlsxColumn("Note", width: 30)]
        let data = Xlsx.workbook([XlsxSheet(name: trip.name.isEmpty ? "Trip" : trip.name, columns: columns, rows: rows)])
        return (Library.workbookFileName(trip.name), data)
    }

    /// "Weekend in the hills packing list.xlsx" — his words kept, only the marks a
    /// file name cannot hold taken out.
    public static func workbookFileName(_ tripName: String) -> String {
        let bare = String(tripName.map { "/:\\?*\"<>|".contains($0) ? " " : $0 })
        let name = jsTrim(bare).isEmpty ? "Trip" : jsTrim(bare)
        return "\(name) packing list.xlsx"
    }
}
