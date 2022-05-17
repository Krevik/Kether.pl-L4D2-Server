HUDTable <-
{
	Fields = 
	{
		logo = { slot = HUD_FAR_RIGHT, dataval = "Kether", flags = HUD_FLAG_ALIGN_LEFT | HUD_FLAG_NOBG, name = "logo" }
	}
}

HUDSetLayout(HUDTable) //Applies a HUD to the screen
//HUDPlace(HUD_FAR_RIGHT, 0.8 , 0.04 , 0.5 , 0.1) //Uncomment this line if you want to configure the text box: make it larger or change it on the screen 
g_ModeScript // Global reference to the Mode Script scope
