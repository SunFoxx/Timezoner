import Foundation

enum CapitalCityIndex {
    struct Entry: Sendable {
        let names: [String]
        let timeZoneIdentifier: String
    }

    static let entries: [Entry] = data.split(separator: "\n").compactMap { line in
        let fields = line.split(separator: "|", omittingEmptySubsequences: true).map(String.init)
        guard let timeZoneIdentifier = fields.first, fields.count > 1 else {
            return nil
        }
        return Entry(names: Array(fields.dropFirst()), timeZoneIdentifier: timeZoneIdentifier)
    }

    // Country and territory capitals are derived from the GeoNames countryInfo and
    // cities15000 datasets (CC BY 4.0), with common multi-capital aliases added.
    private static let data = """
        Europe/Andorra|Andorra la Vella
        Asia/Dubai|Abu Dhabi
        Asia/Kabul|Kabul
        America/Antigua|St. John's|Saint John’s|Saint John's
        America/Anguilla|The Valley
        Europe/Tirane|Tirana
        Asia/Yerevan|Yerevan
        Africa/Luanda|Luanda
        America/Argentina/Buenos_Aires|Buenos Aires
        Pacific/Pago_Pago|Pago Pago
        Europe/Vienna|Vienna
        Australia/Sydney|Canberra
        America/Aruba|Oranjestad
        Europe/Mariehamn|Mariehamn
        Asia/Baku|Baku
        Europe/Sarajevo|Sarajevo
        America/Barbados|Bridgetown
        Asia/Dhaka|Dhaka
        Europe/Brussels|Brussels
        Africa/Ouagadougou|Ouagadougou
        Europe/Sofia|Sofia
        Asia/Bahrain|Manama
        Africa/Bujumbura|Gitega|Bujumbura
        Africa/Porto-Novo|Porto-Novo|Cotonou
        America/St_Barthelemy|Gustavia
        Atlantic/Bermuda|Hamilton
        Asia/Brunei|Bandar Seri Begawan
        America/La_Paz|Sucre|La Paz
        America/Sao_Paulo|Brasilia|Brasília
        America/Nassau|Nassau
        Asia/Thimphu|Thimphu
        Africa/Gaborone|Gaborone
        Europe/Minsk|Minsk
        America/Belize|Belmopan
        America/Toronto|Ottawa
        Indian/Cocos|West Island
        Africa/Kinshasa|Kinshasa
        Africa/Bangui|Bangui
        Africa/Brazzaville|Brazzaville
        Europe/Zurich|Bern
        Africa/Abidjan|Yamoussoukro|Abidjan
        Pacific/Rarotonga|Avarua
        America/Santiago|Santiago
        Africa/Douala|Yaounde|Yaoundé
        Asia/Shanghai|Beijing
        America/Bogota|Bogota|Bogotá
        America/Costa_Rica|San Jose|San José
        America/Havana|Havana
        Atlantic/Cape_Verde|Praia
        America/Curacao|Willemstad
        Indian/Christmas|Flying Fish Cove
        Asia/Nicosia|Nicosia
        Europe/Prague|Prague
        Europe/Berlin|Berlin
        Africa/Djibouti|Djibouti
        Europe/Copenhagen|Copenhagen
        America/Dominica|Roseau
        America/Santo_Domingo|Santo Domingo
        Africa/Algiers|Algiers
        America/Guayaquil|Quito
        Europe/Tallinn|Tallinn
        Africa/Cairo|Cairo
        Africa/El_Aaiun|El-Aaiun|Laayoune
        Africa/Asmara|Asmara
        Europe/Madrid|Madrid
        Africa/Addis_Ababa|Addis Ababa
        Europe/Helsinki|Helsinki
        Pacific/Fiji|Suva
        Atlantic/Stanley|Stanley
        Pacific/Pohnpei|Palikir
        Atlantic/Faroe|Torshavn|Tórshavn
        Europe/Paris|Paris
        Africa/Libreville|Libreville
        Europe/London|London
        America/Grenada|St. George's|Saint George's
        Asia/Tbilisi|Tbilisi
        America/Cayenne|Cayenne
        Europe/Guernsey|St Peter Port|Saint Peter Port
        Africa/Accra|Accra
        Europe/Gibraltar|Gibraltar
        America/Nuuk|Nuuk
        Africa/Banjul|Banjul
        Africa/Conakry|Conakry
        America/Guadeloupe|Basse-Terre
        Africa/Malabo|Ciudad de la Paz|Malabo
        Europe/Athens|Athens
        Atlantic/South_Georgia|Grytviken
        America/Guatemala|Guatemala City
        Pacific/Guam|Hagatna|Hagåtña
        Africa/Bissau|Bissau
        America/Guyana|Georgetown
        Asia/Hong_Kong|Hong Kong
        America/Tegucigalpa|Tegucigalpa
        Europe/Zagreb|Zagreb
        America/Port-au-Prince|Port-au-Prince
        Europe/Budapest|Budapest
        Asia/Jakarta|Jakarta|Nusantara
        Europe/Dublin|Dublin
        Asia/Jerusalem|Jerusalem
        Europe/Isle_of_Man|Douglas
        Asia/Kolkata|New Delhi
        Asia/Baghdad|Baghdad
        Asia/Tehran|Tehran
        Atlantic/Reykjavik|Reykjavik|Reykjavík
        Europe/Rome|Rome
        Europe/Jersey|Saint Helier
        America/Jamaica|Kingston
        Asia/Amman|Amman
        Asia/Tokyo|Tokyo
        Africa/Nairobi|Nairobi
        Asia/Bishkek|Bishkek
        Asia/Phnom_Penh|Phnom Penh
        Pacific/Tarawa|Tarawa
        Indian/Comoro|Moroni
        America/St_Kitts|Basseterre
        Asia/Pyongyang|Pyongyang
        Asia/Seoul|Seoul
        Europe/Belgrade|Pristina
        Asia/Kuwait|Kuwait City
        America/Cayman|George Town
        Asia/Almaty|Astana|Nur-Sultan
        Asia/Vientiane|Vientiane
        Asia/Beirut|Beirut
        America/St_Lucia|Castries
        Europe/Vaduz|Vaduz
        Asia/Colombo|Sri Jayewardenepura Kotte|Colombo
        Africa/Monrovia|Monrovia
        Africa/Maseru|Maseru
        Europe/Vilnius|Vilnius
        Europe/Luxembourg|Luxembourg
        Europe/Riga|Riga
        Africa/Tripoli|Tripoli
        Africa/Casablanca|Rabat
        Europe/Monaco|Monaco
        Europe/Chisinau|Chisinau|Chișinău
        Europe/Podgorica|Podgorica
        America/Marigot|Marigot
        Indian/Antananarivo|Antananarivo
        Pacific/Majuro|Majuro
        Europe/Skopje|Skopje
        Africa/Bamako|Bamako
        Asia/Yangon|Nay Pyi Taw|Naypyidaw
        Asia/Ulaanbaatar|Ulaanbaatar|Ulan Bator
        Asia/Macau|Macao|Macau
        Pacific/Saipan|Saipan
        America/Martinique|Fort-de-France
        Africa/Nouakchott|Nouakchott
        America/Montserrat|Plymouth|Brades
        Europe/Malta|Valletta
        Indian/Mauritius|Port Louis
        Indian/Maldives|Male|Malé
        Africa/Blantyre|Lilongwe
        America/Mexico_City|Mexico City
        Asia/Kuala_Lumpur|Kuala Lumpur|Putrajaya
        Africa/Maputo|Maputo
        Africa/Windhoek|Windhoek
        Pacific/Noumea|Noumea|Nouméa
        Africa/Niamey|Niamey
        Pacific/Norfolk|Kingston
        Africa/Lagos|Abuja
        America/Managua|Managua
        Europe/Amsterdam|Amsterdam|The Hague
        Europe/Oslo|Oslo
        Asia/Kathmandu|Kathmandu
        Pacific/Nauru|Yaren
        Pacific/Niue|Alofi
        Pacific/Auckland|Wellington
        Asia/Muscat|Muscat
        America/Panama|Panama City
        America/Lima|Lima
        Pacific/Tahiti|Papeete
        Pacific/Port_Moresby|Port Moresby
        Asia/Manila|Manila
        Asia/Karachi|Islamabad
        Europe/Warsaw|Warsaw
        America/Miquelon|Saint-Pierre
        Pacific/Pitcairn|Adamstown
        America/Puerto_Rico|San Juan
        Asia/Hebron|East Jerusalem|Ramallah
        Europe/Lisbon|Lisbon
        America/Asuncion|Asuncion|Asunción
        Asia/Qatar|Doha
        Indian/Reunion|Saint-Denis
        Europe/Bucharest|Bucharest
        Europe/Belgrade|Belgrade
        Europe/Moscow|Moscow
        Africa/Kigali|Kigali
        Asia/Riyadh|Riyadh
        Pacific/Guadalcanal|Honiara
        Indian/Mahe|Victoria
        Africa/Khartoum|Khartoum
        Africa/Juba|Juba
        Europe/Stockholm|Stockholm
        Asia/Singapore|Singapore
        Atlantic/St_Helena|Jamestown
        Europe/Ljubljana|Ljubljana
        Arctic/Longyearbyen|Longyearbyen
        Europe/Bratislava|Bratislava
        Africa/Freetown|Freetown
        Europe/San_Marino|San Marino
        Africa/Dakar|Dakar
        Africa/Mogadishu|Mogadishu
        America/Paramaribo|Paramaribo
        Africa/Sao_Tome|Sao Tome|São Tomé
        America/El_Salvador|San Salvador
        America/Lower_Princes|Philipsburg
        Asia/Damascus|Damascus
        Africa/Mbabane|Mbabane|Lobamba
        America/Grand_Turk|Cockburn Town
        Africa/Ndjamena|N'Djamena
        Indian/Kerguelen|Port-aux-Francais|Port-aux-Français
        Africa/Lome|Lome|Lomé
        Asia/Bangkok|Bangkok
        Asia/Dushanbe|Dushanbe
        Asia/Dili|Dili
        Asia/Ashgabat|Ashgabat
        Africa/Tunis|Tunis
        Pacific/Tongatapu|Nuku'alofa|Nuku‘alofa
        Europe/Istanbul|Ankara
        America/Port_of_Spain|Port of Spain
        Pacific/Funafuti|Funafuti
        Asia/Taipei|Taipei
        Africa/Dar_es_Salaam|Dodoma|Dar es Salaam
        Europe/Kyiv|Kyiv|Kiev
        Africa/Kampala|Kampala
        America/New_York|Washington|Washington D.C.|Washington DC
        America/Montevideo|Montevideo
        Asia/Tashkent|Tashkent
        Europe/Vatican|Vatican City
        America/St_Vincent|Kingstown
        America/Caracas|Caracas
        America/Tortola|Road Town
        America/St_Thomas|Charlotte Amalie
        Asia/Bangkok|Hanoi
        Pacific/Efate|Port Vila|Port-Vila
        Pacific/Wallis|Mata Utu|Mata-Utu
        Pacific/Apia|Apia
        Asia/Aden|Sanaa|Sana'a|Aden
        Indian/Mayotte|Mamoudzou
        Africa/Johannesburg|Pretoria|Cape Town|Bloemfontein
        Africa/Lusaka|Lusaka
        Africa/Harare|Harare
        Indian/Chagos|Diego Garcia
        Pacific/Palau|Ngerulmud|Melekeok
        """
}
