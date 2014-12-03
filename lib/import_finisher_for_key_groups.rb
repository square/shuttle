# Copyright 2014 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

# Contains hooks run by Sidekiq upon completion of a key group import batch.

class ImportFinisherForKeyGroups

  # Run by Sidekiq after a KeyGroup's import batch finishes successfully.
  # Unsets the {KeyGroup}'s `loading` flag.
  # Recalculates readiness for the {Key Keys} in the KeyGroup, and for the
  # {KeyGroup} itself.

  def on_success(_status, options)
    key_group = KeyGroup.find(options['key_group_id'])

    # finish loading
    key_group.update_import_finishing_fields!

    # the readiness hooks were all disabled, so now we need to go through and
    # calculate readiness and stats.
    recalculate_full_readiness!(key_group)
  end

  private

  # Recalculates readiness, first, for the {Key Keys} in the KeyGroup, and then
  # for the {KeyGroup} itself.

  # TODO (yunus): Key.batch_recalculate_ready! can be generalized to include key_groups
  # recalculating every key separately is slow

  def recalculate_full_readiness!(key_group)
    key_group.keys.each do |key|
      key.skip_readiness_hooks = true
      key.recalculate_ready!
    end
    key_group.recalculate_ready!
  end
end
