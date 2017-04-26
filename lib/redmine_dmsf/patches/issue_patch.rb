# encoding: utf-8
#
# Redmine plugin for Document Management System "Features"
#
# Copyright (C) 2011-17 Karel Pičman <karel.picman@kontron.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module RedmineDmsf
  module Patches
    module IssuePatch

      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          unloadable
          before_destroy :delete_system_folder
        end
      end

      module InstanceMethods

        def system_folder(create = false)
          parent = DmsfFolder.system.where(:project_id => self.project_id, :title => '.Issues').first
          if create && !parent
            parent = DmsfFolder.new
            parent.project_id = self.project_id
            parent.title = '.Issues'
            parent.description = 'Documents assigned to issues'
            parent.user_id = User.anonymous.id
            parent.system = true
            parent.save
          end
          if parent
            folder = DmsfFolder.system.where(['project_id = ? AND dmsf_folder_id = ? AND CAST(title AS UNSIGNED) = ?',
              self.project_id, parent.id, self.id]).first
            if create && !folder
              folder = DmsfFolder.new
              folder.dmsf_folder_id = parent.id
              folder.project_id = self.project_id
              folder.title = "#{self.id} - #{self.subject}"
              folder.user_id = User.anonymous.id
              folder.system = true
              folder.save
            end
          end
          folder
        end

        def dmsf_files
          folder = self.system_folder
          folder.dmsf_files if folder
        end

        def delete_system_folder
          folder = self.system_folder
          folder.destroy if folder
        end

        def dmsf_file_added(dmsf_file)
          unless dmsf_file.new_record?
            self.journalize_dmsf_file(dmsf_file, :added)
          end
        end

        def dmsf_file_removed(dmsf_file)
          unless dmsf_file.new_record?
            self.journalize_dmsf_file(dmsf_file, :removed)
          end
        end

        # Adds a journal detail for an attachment that was added or removed
        def journalize_dmsf_file(dmsf_file, added_or_removed)
          init_journal(User.current)
          key = (added_or_removed == :removed ? :old_value : :value)
          current_journal.details << JournalDetail.new(
            :property => 'dmsf_file',
            :prop_key => dmsf_file.id,
            key => dmsf_file.title
          )
          current_journal.save
        end
      end

    end
  end
end

# Apply patch
Rails.configuration.to_prepare do
  unless Issue.included_modules.include?(RedmineDmsf::Patches::IssuePatch)
    Issue.send(:include, RedmineDmsf::Patches::IssuePatch)
  end
end
