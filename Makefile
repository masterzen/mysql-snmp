# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.	If not, see <http://www.gnu.org/licenses/>.

build:

install:
	install -m 755 mysql-agent $(DESTDIR)/usr/sbin/mysql-agent
	install -m 644 MYSQL-SERVER-MIB.txt $(DESTDIR)/usr/share/snmp/mibs
	install -m 644 mysql-agent.1 $(DESTDIR)/usr/share/man/man1
	gzip $(DESTDIR)/usr/share/man/man1

clean:
	-rm $(DESTDIR)/usr/sbin/mysql-agent
	
