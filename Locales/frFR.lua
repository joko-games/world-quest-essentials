if GetLocale() ~= "frFR" then
    return
end

local _, ns = ...

ns.Translation = {
    ["World Quests"] = "Expéditions",
    ["Search"] = "Rechercher",
    ["All"] = "Tout",
    ["Gear"] = "Équipement",
    ["Gold"] = "Or",
    ["Currency"] = "Monnaies",
    ["Reputation"] = "Réputation",
    ["Items"] = "Objets",
    ["Quest"] = "Expédition",
    ["Zone"] = "Zone",
    ["Time"] = "Temps",
    ["No world quest matches."] = "Aucune expédition ne correspond.",
    ["No world quest available."] = "Aucune expédition disponible.",
    ["Rewards"] = "Récompenses",
    ["Maps scanned:"] = "Cartes parcourues :",
    ["Commands: /wqe maps (the maps scanned)."] = "Commandes : /wqe maps (les cartes parcourues).",
    ["Loading"] = "Chargement",
    ["Type"] = "Type",
    ["Value"] = "Valeur",
}

-- The Type column's short labels.
ns.TypeLabels = {
    gear = "Équip.", items = "Objet", currency = "Monnaie", gold = "Or", reputation = "Répu.",
}
