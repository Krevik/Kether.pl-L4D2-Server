HUDTable <-
{
	Fields = 
	{
		logo = { slot = HUD_FAR_RIGHT, dataval = "Kether.pl", flags = HUD_FLAG_ALIGN_LEFT | HUD_FLAG_NOBG, name = "logo" }
	}
}

HUDSetLayout(HUDTable) //Applies a HUD to the screen
//HUDPlace(HUD_FAR_RIGHT, 0.90 , 0.0 , 0.05 , 0.03) //Uncomment this line if you want to configure the text box: make it larger or change it on the screen 
g_ModeScript // Global reference to the Mode Script scope
