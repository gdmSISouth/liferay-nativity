/**
 * Copyright (c) 2000-2013 Liferay, Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License as published by the Free
 * Software Foundation; either version 2.1 of the License, or (at your option)
 * any later version.
 *
 * This library is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
 * details.
 */

#define PORT							33001
#define CONTEXT_MENU_GUID				L"{0DD5B4B0-25AF-4e09-A46B-9F274F3D7000}"

//DLL Registration information
#define REGISTRY_ALL_CONTEXT_MENU		L"*\\shellex\\ContextMenuHandlers\\LiferayNativityContextMenus"
#define REGISTRY_FOLDER_CONTEXT_MENU	L"Folder\\shellex\\ContextMenuHandlers\\LiferaySyncContextMenus"
#define REGISTRY_CLSID					L"CLSID"
#define REGISTRY_IN_PROCESS				L"InprocServer32"
#define REGISTRY_THREADING				L"ThreadingModel"
#define REGISTRY_APARTMENT				L"Apartment"
#define REGISTRY_VERSION				L"Version"
#define REGISTRY_VERSION_NUMBER			L"1.0"

//Menu Util
#define SEPARATOR						L"_SEPARATOR_"

//Remote Functions
#define GET_CONTEXT_MENU_LIST			L"getContextMenuList"
#define PERFORM_ACTION					L"performAction"

//Model
#define ID								L"id"
#define FILES							L"files"

#define SEPARATOR						L"_SEPARATOR_"
#define CONTEXT_MENU_ITEMS				L"contextMenuItems"
#define ENABLED							L"enabled"
#define HELP_TEXT						L"helpText"
#define TITLE							L"title"

#define TRUE_TEXT						L"true"