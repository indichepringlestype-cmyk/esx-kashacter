fx_version 'cerulean'
game 'gta5'

name 'esx_multicharacter'
author 'indichepringlestype'
description 'Multicharacter for ESX Legacy 1.13.5 REMAKE'
version '1.4.2'
repository 'https://github.com/indichepringlestype-cmyk/esx-kashacter'
lua54 'yes'

dependencies {
	'es_extended',
	'oxmysql',
	'esx_menu_default',
	'esx_identity',
	'esx_skin',
	'skinchanger',
}

shared_scripts {
	'@es_extended/locale.lua',
	'locales/*.lua',
	'config.lua'
}

server_scripts {
	'@es_extended/imports.lua',
	'@oxmysql/lib/MySQL.lua',
	'server/*.lua',
}

client_scripts {
	'client/*.lua'
}

ui_page {
	'html/ui.html',
}

files {
	'html/ui.html',
	'html/css/main.css',
	'html/js/app.js',
}
