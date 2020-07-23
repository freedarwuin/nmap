#!/usr/bin/env python
# -*- coding: utf-8 -*-

# ***********************IMPORTANT NMAP LICENSE TERMS************************
# *                                                                         *
# * The Nmap Security Scanner is (C) 1996-2022 Nmap Software LLC ("The Nmap *
# * Project"). Nmap is also a registered trademark of the Nmap Project.     *
# *                                                                         *
# * This program is distributed under the terms of the Nmap Public Source   *
# * License (NPSL). The exact license text applying to a particular Nmap    *
# * release or source code control revision is contained in the LICENSE     *
# * file distributed with that version of Nmap or source code control       *
# * revision. More Nmap copyright/legal information is available from       *
# * https://nmap.org/book/man-legal.html, and further information on the    *
# * NPSL license itself can be found at https://nmap.org/npsl/ . This       *
# * header summarizes some key points from the Nmap license, but is no      *
# * substitute for the actual license text.                                 *
# *                                                                         *
# * Nmap is generally free for end users to download and use themselves,    *
# * including commercial use. It is available from https://nmap.org.        *
# *                                                                         *
# * The Nmap license generally prohibits companies from using and           *
# * redistributing Nmap in commercial products, but we sell a special Nmap  *
# * OEM Edition with a more permissive license and special features for     *
# * this purpose. See https://nmap.org/oem/                                 *
# *                                                                         *
# * If you have received a written Nmap license agreement or contract       *
# * stating terms other than these (such as an Nmap OEM license), you may   *
# * choose to use and redistribute Nmap under those terms instead.          *
# *                                                                         *
# * The official Nmap Windows builds include the Npcap software             *
# * (https://npcap.com) for packet capture and transmission. It is under    *
# * separate license terms which forbid redistribution without special      *
# * permission. So the official Nmap Windows builds may not be              *
# * redistributed without special permission (such as an Nmap OEM           *
# * license).                                                               *
# *                                                                         *
# * Source is provided to this software because we believe users have a     *
# * right to know exactly what a program is going to do before they run it. *
# * This also allows you to audit the software for security holes.          *
# *                                                                         *
# * Source code also allows you to port Nmap to new platforms, fix bugs,    *
# * and add new features.  You are highly encouraged to submit your         *
# * changes as a Github PR or by email to the dev@nmap.org mailing list     *
# * for possible incorporation into the main distribution. Unless you       *
# * specify otherwise, it is understood that you are offering us very       *
# * broad rights to use your submissions as described in the Nmap Public    *
# * Source License Contributor Agreement. This is important because we      *
# * fund the project by selling licenses with various terms, and also       *
# * because the inability to relicense code has caused devastating          *
# * problems for other Free Software projects (such as KDE and NASM).       *
# *                                                                         *
# * The free version of Nmap is distributed in the hope that it will be     *
# * useful, but WITHOUT ANY WARRANTY; without even the implied warranty of  *
# * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. Warranties,        *
# * indemnification and commercial support are all available through the    *
# * Npcap OEM program--see https://nmap.org/oem/                            *
# *                                                                         *
# ***************************************************************************/

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk

from zenmapCore.UmitConf import CommandProfile
import zenmapCore.I18N  # lgtm[py/unused-import]


class ProfileCombo(Gtk.ComboBox, object):
    def __init__(self):
        Gtk.ComboBox.__init__(self, model=Gtk.ListStore(str), has_entry=True)

        self.completion = Gtk.EntryCompletion()
        self.get_child().set_completion(self.completion)
        self.completion.set_model(self.get_model())
        self.completion.set_text_column(0)

        self.update()

    def set_profiles(self, profiles):
        list = self.get_model()
        for i in range(len(list)):
            iter = list.get_iter_first()
            del(list[iter])

        for command in profiles:
            list.append([command])

    def update(self):
        profile = CommandProfile()
        profiles = profile.sections()
        profiles.sort()
        del(profile)

        self.set_profiles(profiles)

    def get_selected_profile(self):
        return self.get_child().get_text()

    def set_selected_profile(self, profile):
        self.get_child().set_text(profile)

    selected_profile = property(get_selected_profile, set_selected_profile)

if __name__ == "__main__":
    w = Gtk.Window()
    p = ProfileCombo()
    p.update()
    w.add(p)
    w.show_all()

    Gtk.main()
