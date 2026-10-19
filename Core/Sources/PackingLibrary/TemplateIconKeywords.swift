import Foundation
import PackingCore

// Search in the icon picker (0.91) — his words (19 Oct 2026): "Also add the possibility to search
// for icons, and also add alternative names so that the search is easier to perform. But I don't
// know if the alternative names need to be visible, but it would be good to get more hits when
// searching."
//
// Each icon is found by its label (what the picker writes under it) AND by other words for it —
// English, and the Swedish and German he might type ("flyg" finds the Plane, "cykel" the Bike,
// "Wohnmobil" the Camper). The other words are NOT shown: they are only there to be found by, so
// the picker stays as he liked it. Matched as the app's searches match (`normName`: case and runs
// of spaces do not count), as one phrase anywhere in a word ("sim" finds "simma", "bad" both "bad"
// and "badring"), and with accents as How it works counts them (`GuideSearch`) — one step kinder:
// an accent LEFT OUT does not count ("fjall" finds "fjäll", "schlussel" "Schlüssel"), but one he
// TYPES does, because in Swedish å, ä and ö are letters of their own ("båt" is a boat, and must
// not find "bath" or "sunbathing" as the guide's rule would). The
// headings (Travel, Sport …) are not searched: "food" would bring all thirteen of City, food and
// fun. A key never changes; these words may — they are stored nowhere.
//
// 0.92 (his "Could we add some icons again. Love the one we have.", 19 Oct 2026): the 41 new icons
// have theirs too, under "// 0.92" in each heading — never a word that would widen an old search
// he relies on ("flyg" still finds the Plane alone, "båt" the Ferry and Sailing, "strand" the four
// beach icons, "fahrrad" the Bike alone: the bike helmet is "radhelm", its pump "luftpumpe").

extension TemplateIconCatalog {
    /// The other words each icon is found by, by its key — hidden, never shown in the picker.
    public static let keywords: [String: [String]] = [
        // MARK: Travel
        "car": ["auto", "automobile", "drive", "driving", "road trip", "roadtrip", "rental car",
                "bil", "bilresa", "köra", "hyrbil", "autofahrt", "fahren", "mietwagen", "pkw"],
        "plane": ["flight", "fly", "flying", "airplane", "aeroplane", "airport", "air travel",
                  "flyg", "flyga", "flygplan", "flygplats", "flug", "flugzeug", "fliegen", "flughafen"],
        "rv": ["rv", "motorhome", "motor home", "campervan", "camper van", "caravan", "van",
               "husbil", "husvagn", "wohnmobil", "wohnwagen", "campingbus"],
        "train": ["rail", "railway", "tåg", "tågresa", "järnväg", "zug", "bahn", "eisenbahn"],
        "bus": ["coach", "buss", "bussresa", "reisebus"],
        "motorbike": ["motorcycle", "moped", "scooter", "motorcykel", "mc", "motorrad", "roller"],
        "ferry": ["boat", "ship", "cruise", "färja", "båt", "fartyg", "kryssning", "fähre", "schiff", "boot", "kreuzfahrt"],
        "suitcase": ["suitcase", "luggage", "trip", "holiday", "vacation", "resväska", "resa", "semester", "bagage",
                     "koffer", "reise", "urlaub", "gepäck"],
        "weekendbag": ["weekend", "holdall", "duffel", "short trip", "overnight", "helg", "weekendväska", "kort resa",
                       "wochenende", "reisetasche", "kurztrip"],
        "backpack": ["rucksack", "daypack", "ryggsäck", "dagsryggsäck", "tagesrucksack"],
        "box": ["box", "moving", "storage", "parcel", "package", "låda", "kartong", "flytt", "kiste", "karton", "umzug", "paket"],
        "passport": ["id", "documents", "visa", "pass", "legitimation", "reisepass", "ausweis", "dokumente"],
        "ticket": ["ticket", "boarding pass", "biljett", "boardingkort", "fahrkarte", "eintrittskarte"],
        "map": ["route", "navigation", "karta", "karte", "landkarte"],
        "hotel": ["accommodation", "stay", "lodging", "hostel", "b&b", "hotell", "boende", "unterkunft", "übernachtung"],

        // 0.92
        "cottage": ["cabin", "holiday home", "summer house", "house", "stuga", "sommarstuga", "fritidshus", "hus",
                    "ferienhaus", "hütte", "haus"],
        "globe": ["globe", "world", "international", "overseas", "utomlands", "utlandet", "världen", "ausland", "welt",
                  "weltreise"],
        "pillow": ["travel pillow", "cushion", "nap", "nackkudde", "resekudde", "kudde", "nackenkissen", "reisekissen"],
        "scooter": ["electric scooter", "kick scooter", "elsparkcykel", "sparkcykel", "elscooter", "e-roller", "tretroller"],

        // MARK: Outdoors
        "hiking": ["hike", "trek", "trekking", "trail", "mountains", "vandring", "vandra", "fjällvandring",
                   "wandern", "wanderung", "bergwandern"],
        "walk": ["walk", "stroll", "promenade", "promenad", "gå", "spaziergang", "spazieren", "gehen"],
        "mountain": ["mountain", "peak", "alpine", "top", "fjäll", "berg", "topp", "gipfel", "alpen"],
        "compass": ["compass", "navigation", "kompass", "orientering", "orientierungslauf"],
        "tent": ["tent", "camp", "tält", "tälta", "zelt", "zelten"],
        "fire": ["fire", "bonfire", "lägereld", "eld", "brasa", "lagerfeuer", "feuer"],
        "headlamp": ["head torch", "torch", "flashlight", "lamp", "light", "pannlampa", "ficklampa", "lampa",
                     "stirnlampe", "taschenlampe"],
        "ski": ["ski", "cross-country", "downhill", "slalom", "skidor", "skidåkning", "längdskidor",
                "skifahren", "langlauf"],
        "snow": ["snow", "cold", "snö", "vinter", "kyla", "schnee", "kälte"],
        "rain": ["rainy", "wet", "weather", "regn", "regnig", "väder", "regen", "wetter"],
        "fishing": ["fish", "angling", "fiske", "fiska", "angeln", "fischen"],

        // 0.92
        "xcski": ["cross-country skiing", "nordic skiing", "xc", "längdskidor", "längdåkning", "vasaloppet", "langlauf",
                  "skilanglauf", "loipe"],
        "skate": ["skates", "ice skates", "skridskor", "skridsko", "långfärdsskridsko", "schlittschuh", "eislaufen"],
        "sled": ["sledge", "toboggan", "sledding", "kälke", "pulka", "åka pulka", "schlitten", "rodeln"],
        "sleepingbag": ["mummy bag", "bivouac", "sovsäck", "sovpåse", "schlafsack", "biwak"],
        "binoculars": ["field glasses", "birdwatching", "safari", "kikare", "fågelskådning", "fernglas", "vogelbeobachtung"],
        "thermos": ["flask", "vacuum flask", "hot drink", "termos", "termosflaska", "thermosflasche", "thermoskanne"],
        "mittens": ["gloves", "mitts", "winter gloves", "vantar", "vante", "handskar", "fäustlinge", "handschuhe"],
        "jacket": ["coat", "rain jacket", "raincoat", "down jacket", "jacka", "regnjacka", "dunjacka", "jacke", "regenjacke"],
        "mushroom": ["mushroom picking", "forest", "chanterelles", "svamp", "svampplockning", "kantareller", "skog",
                     "pilze", "pilze sammeln", "wald"],

        // MARK: Sport
        "run": ["running", "jog", "jogging", "race", "marathon", "löpning", "springa", "jogga", "laufen", "joggen"],
        "bike": ["cycling", "bicycle", "cycle", "mtb", "road bike", "cykel", "cykling", "cykla",
                 "fahrrad", "radfahren", "rad"],
        "swim": ["swimming", "pool", "bath", "open water", "simma", "simning", "bad", "bada", "simhall",
                 "schwimmen", "schwimmbad", "baden"],
        "triathlon": ["ironman", "race", "medal", "tävling", "medalj", "wettkampf", "medaille"],
        "diving": ["dive", "scuba", "snorkel", "mask", "dykning", "dyka", "snorkla", "tauchen", "schnorcheln"],
        "fin": ["apnea", "fins", "flippers", "fridykning", "simfötter", "apnoe", "freitauchen", "flossen"],
        "kayak": ["kayak", "canoe", "paddle", "sup", "kajak", "kanot", "paddla", "kanu", "paddeln"],
        "climb": ["climb", "bouldering", "rope", "klättring", "klättra", "klettern", "bouldern"],
        "golf": ["golf course", "golfbana", "golfplatz"],
        "racket": ["tennis", "padel", "badminton", "squash", "table tennis", "ping pong", "racket", "bordtennis",
                   "racketsport", "tischtennis", "schläger"],
        "strength": ["gym", "weights", "barbell", "lifting", "styrka", "styrketräning", "vikter", "krafttraining",
                     "fitnessstudio", "hantel"],
        "kettlebell": ["weight", "gym", "vikt", "kugelhantel"],
        "mobility": ["rörlighet", "mobilität", "beweglichkeit"],
        "yoga": ["stretching", "warm-up", "stretcha", "töjning", "dehnen", "dehnung"],
        "lotus": ["meditation", "mindfulness", "meditera", "achtsamkeit"],
        "breath": ["breathing", "breathwork", "wind", "andning", "andas", "atmung", "atemübung"],
        "sauna": ["steam", "bastu", "basta", "dampfbad"],
        "icebath": ["cold plunge", "cold water", "winter swim", "isbad", "kallbad", "vinterbad", "eisbad", "eisbaden"],
        "watch": ["clock", "time", "sports watch", "klocka", "armbandsur", "tid", "uhr", "armbanduhr", "zeit"],
        "bottle": ["water", "drink", "hydration", "vattenflaska", "flaska", "vatten", "wasserflasche", "flasche",
                   "wasser", "trinken"],

        // 0.92
        "rowing": ["row", "rower", "erg", "ergometer", "rowing machine", "concept2", "rodd", "roddmaskin", "rudern",
                   "rudergerät"],
        "stopwatch": ["timer", "lap", "split", "pace", "stoppur", "tidtagning", "stoppuhr", "zeitmessung"],
        "pulse": ["pulse", "heart rate monitor", "chest strap", "puls", "pulsband", "pulsmätare", "herzfrequenz", "pulsgurt"],
        "trophy": ["cup", "race", "competition", "winner", "podium", "pokal", "tävling", "lopp", "vinnare", "wettkampf",
                   "siegerpokal"],
        "helmet": ["helmet", "cycling helmet", "cykelhjälm", "hjälm", "helm", "radhelm"],
        "pump": ["pump", "tyre", "tire", "puncture", "cykelpump", "pumpa", "punktering", "luftpumpe", "pumpe", "reifen"],
        "wetsuit": ["neoprene", "open water", "dry suit", "våtdräkt", "torrdräkt", "neoprenanzug", "taucheranzug"],
        "tank": ["air tank", "cylinder", "regulator", "dykflaska", "luftflaska", "tauchflasche", "pressluftflasche"],
        "yogamat": ["mat", "exercise mat", "training mat", "yogamatta", "träningsmatta", "matta", "yogamatte", "matte"],
        "sup": ["sup", "stand up paddle", "paddle board", "board", "brädpaddling", "paddelbräda", "stehpaddeln"],
        "lifejacket": ["life vest", "buoyancy aid", "pfd", "flytväst", "räddningsväst", "schwimmweste", "rettungsweste"],

        // MARK: Beach and summer
        "sun": ["sun", "sunny", "heat", "sol", "sommar", "värme", "sonne", "sommer", "hitze"],
        "lounger": ["beach", "sunbathing", "sunbed", "deckchair", "strand", "sola", "solstol", "liegestuhl",
                    "sonnenliege", "sonnen"],
        "beach": ["umbrella", "parasol", "sea", "strand", "parasoll", "hav", "sonnenschirm", "meer"],
        "palm": ["palm", "tropical", "island", "tropisk", "ö", "palme", "tropisch", "insel"],
        "glasses": ["glasses", "shades", "solglasögon", "glasögon", "sonnenbrille", "brille"],
        "sunhat": ["hat", "cap", "solhatt", "hatt", "keps", "sonnenhut", "hut", "mütze"],
        "suncream": ["sunscreen", "spf", "lotion", "solkräm", "solskydd", "sonnencreme", "sonnenschutz"],
        "flipflops": ["sandals", "slippers", "thongs", "flipflops", "sandaler", "tofflor", "sandalen", "badelatschen"],
        "towel": ["beach towel", "handduk", "badlakan", "handtuch", "badetuch", "strandtuch"],
        "beachball": ["ball", "games", "boll", "badboll", "wasserball", "strandball"],
        "swimring": ["float", "inflatable", "lifebuoy", "badring", "flytring", "schwimmring", "schwimmreifen"],
        "shell": ["seashell", "scallop", "snäcka", "mussla", "muschel"],
        "surf": ["surf", "wave", "surfa", "våg", "surfen", "welle"],
        "sail": ["sail", "boat", "yacht", "segla", "segling", "segelbåt", "båt", "segeln", "segelboot", "boot"],
        "kite": ["kitesurfing", "drake", "drachen", "kitesurfen"],

        // 0.92
        "icecream": ["gelato", "cone", "dessert", "glass", "glassstrut", "eis", "eiscreme", "eiswaffel"],
        "bucket": ["bucket", "spade", "sandcastle", "sandpit", "hink", "sandslott", "sandlåda", "eimer", "schaufel",
                   "sandburg", "sandkasten"],
        "anchor": ["boat", "boating", "harbour", "marina", "archipelago", "ankare", "hamn", "skärgård", "gästhamn",
                   "anker", "hafen"],
        "midsummer": ["maypole", "midsommar", "midsommarstång", "majstång", "midsommarafton", "mittsommer", "maibaum"],

        // MARK: City, food and fun
        "city": ["town", "city break", "sightseeing", "stad", "storstad", "stadsresa", "stadt", "städtereise"],
        "restaurant": ["dinner", "eating out", "dining", "restaurang", "middag", "äta ute", "abendessen", "essen gehen"],
        "food": ["meal", "lunch", "eat", "mat", "äta", "måltid", "essen", "mahlzeit", "mittagessen"],
        "coffee": ["café", "tea", "fika", "kaffe", "te", "kaffee", "tee"],
        "wine": ["drinks", "bar", "vin", "dryck", "wein", "getränke"],
        "picnic": ["basket", "picknick", "korg", "korb"],
        "bbq": ["bbq", "grill", "grilling", "grilla", "grillen"],
        "shopping": ["shop", "bag", "handla", "shoppa", "kasse", "einkaufen", "tasche"],
        "party": ["celebration", "birthday", "festival", "fest", "kalas", "firande", "födelsedag", "feier", "geburtstag"],
        "gift": ["present", "christmas", "gåva", "jul", "geschenk", "weihnachten"],
        "music": ["concert", "festival", "musik", "konsert", "konzert"],
        "camera": ["photo", "photography", "pictures", "kamera", "foto", "fotografera", "fotografie"],
        "book": ["book", "read", "novel", "bok", "läsa", "läsning", "buch", "lesen", "roman"],

        // 0.92
        "pizza": ["pizzeria", "slice", "italian", "fast food", "italiensk mat", "snabbmat", "italienisch", "imbiss"],
        "museum": ["gallery", "art", "exhibition", "museer", "konst", "utställning", "galleri", "ausstellung", "kunst",
                   "galerie"],
        "cake": ["cake", "birthday cake", "candles", "tårta", "födelsedagstårta", "födelsedag", "kalas", "kuchen",
                 "torte", "geburtstag"],
        "rings": ["rings", "wedding rings", "marriage", "engagement", "anniversary", "bröllop", "vigselringar", "ringar",
                  "förlovning", "hochzeit", "eheringe"],
        "xmastree": ["christmas tree", "xmas", "advent", "jul", "julgran", "julafton", "weihnachten", "weihnachtsbaum",
                     "tannenbaum"],
        "cinema": ["movie", "movies", "film", "bio", "biograf", "kino"],
        "ferriswheel": ["theme park", "amusement park", "ferris wheel", "funfair", "nöjespark", "tivoli", "pariserhjul",
                        "liseberg", "gröna lund", "freizeitpark", "riesenrad", "kirmes"],

        // MARK: Everyday
        "laptop": ["laptop", "computer", "office", "dator", "jobb", "arbete", "kontor", "arbeit", "büro"],
        "briefcase": ["business trip", "meeting", "conference", "tjänsteresa", "affärsresa", "möte", "konferens",
                      "geschäftsreise", "dienstreise", "konferenz"],
        "phone": ["mobile", "smartphone", "iphone", "telefon", "mobil", "handy"],
        "plug": ["charger", "cable", "plug", "adapter", "power", "laddare", "kabel", "elektronik", "ladegerät", "stecker"],
        "headphones": ["earphones", "airpods", "audio", "hörlurar", "kopfhörer"],
        "wallet": ["wallet", "cash", "cards", "plånbok", "pengar", "kontanter", "geldbörse", "geld", "portemonnaie"],
        "keys": ["key", "house", "home", "nycklar", "nyckel", "schlüssel"],
        "clothes": ["clothing", "shirt", "t-shirt", "kläder", "tröja", "kleidung", "hemd"],
        "shoes": ["sneakers", "boots", "footwear", "skor", "kängor", "schuhe", "stiefel"],
        "laundry": ["washing", "washing machine", "tvätt", "tvätta", "tvättmaskin", "wäsche", "waschen", "waschmaschine"],
        "toiletry": ["toilet bag", "wash bag", "shampoo", "soap", "necessär", "hygien", "tvål", "kulturbeutel",
                     "hygiene", "seife"],
        "pill": ["medicine", "pills", "medication", "tablets", "medicin", "tabletter", "medikamente", "tabletten", "medizin"],
        "firstaid": ["plasters", "bandage", "kit", "första hjälpen", "plåster", "erste hilfe", "pflaster", "verbandskasten"],
        "heart": ["heart", "love", "hälsa", "hjärta", "gesundheit", "herz"],
        "sleep": ["sleep", "bed", "night", "sova", "säng", "natt", "schlafen", "bett", "nacht"],
        "kids": ["children", "family", "baby", "barn", "familj", "kinder", "familie"],
        "paw": ["pet", "puppy", "cat", "hund", "husdjur", "katt", "haustier", "katze"],

        // 0.92
        "toothbrush": ["teeth", "dental", "toothpaste", "tandborste", "tandkräm", "tänder", "zahnbürste", "zahnpasta",
                       "zähne"],
        "battery": ["power bank", "powerbank", "charging", "batteri", "laddning", "ladda", "akku", "batterie", "aufladen"],
        "badge": ["lanyard", "id badge", "conference badge", "access card", "namnbricka", "passerkort", "konferens",
                  "namensschild", "tagung", "messe"],
        "notebook": ["notebook", "notepad", "journal", "diary", "anteckningar", "anteckningsbok", "dagbok", "notizbuch",
                     "notizen", "tagebuch"],
        "suit": ["tie", "necktie", "formal", "dress code", "business attire", "kostym", "slips", "finkläder", "anzug",
                 "krawatte"],
        "pram": ["stroller", "pushchair", "buggy", "baby", "barnvagn", "sittvagn", "kinderwagen"],
    ]

    /// Does this icon answer the search — its label or one of its other words holding the words
    /// typed (as one phrase; case, spaces and accents not counting)? Every icon does for a
    /// search with nothing in it.
    public static func matches(_ icon: TemplateIcon, _ query: String) -> Bool {
        let needle = GuideSearch.needle(query)
        if needle.isEmpty { return true }
        // An accent typed counts; one left out does not (see the top of this file).
        let plain = needle.folding(options: .diacriticInsensitive, locale: nil) == needle
        let options: String.CompareOptions = plain ? [.caseInsensitive, .diacriticInsensitive] : [.caseInsensitive]
        func holds(_ text: String) -> Bool { text.range(of: needle, options: options) != nil }
        return holds(icon.label) || (keywords[icon.key] ?? []).contains(where: holds)
    }

    /// The icons a search finds, in the picker's order; all of them for an empty search.
    public static func find(_ query: String) -> [TemplateIcon] { all.filter { matches($0, query) } }

    /// The picker's headings with the icons the search finds under each, in the picker's order —
    /// a heading with none of them left out (as Find a thing on a template leaves a heading out).
    public static func grouped(matching query: String) -> [(group: TemplateIconGroup, icons: [TemplateIcon])] {
        grouped.compactMap { section in
            let icons = section.icons.filter { matches($0, query) }
            return icons.isEmpty ? nil : (section.group, icons)
        }
    }
}
