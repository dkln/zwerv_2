"""De basiscomposities waar alle muziek van het spel van gemaakt wordt (tools/muziek/build.py,
docs/MUZIEK.md "De basissoundtracks"):

    ACTIEF    primair: de intro, en de andere deuntjes en liedjes (de handelaar, de kaart, de
              missie- en taakdeuntjes, gewonnen, dood, de supermarkten)
    MENU      secundair: het menu (letterlijk), en daarvan afgeleid de karakterkeuze, het
              laadscherm, de stad, de beloning en level omhoog (derive.SECONDARY_PIECES)
    GEVECHT   tertiair: de vechtscène, letterlijk: het hele nummer, één bestand (gevecht.ogg);
              leeg: geen. Hier wordt niets van afgeleid.

Een andere compositie proberen zonder dit te veranderen: ZWERVR_COMPOSITIE=<naam> (primair),
ZWERVR_MENU_COMPOSITIE=<naam> (secundair), ZWERVR_GEVECHT_COMPOSITIE=<naam> (tertiair)."""
ACTIEF = "nitro_overdrive_92"
MENU = "street_viper_92"
GEVECHT = "neon_knuckle"
