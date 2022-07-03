Srcds (init.d and systemd) services – choose the most suitable for you:
  /etc:       system-mode
  ~/.config:  user-mode (secure, but requires a clean user logon (not through "su"), or a user setup script, 
			see: https://unix.forumming.com/question/1880/starting-a-systemd-user-instance-for-a-user-from-a-shell
			user's lingering must be enabled as well:
			https://wiki.archlinux.org/title/systemd/User#Automatic_start-up_of_systemd_user_instances
			`sudo loginctl enable-linger steam`)
