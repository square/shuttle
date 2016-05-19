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

# Mixin that adds the ability to traverse the blobs of a `Rugged::Commit`.

module CommitTraverser

  # Recursively scans the trees of a commit, locating and yielding blobs. Will
  # run indefinitely if there are cycles in the tree graph.
  #
  # @param [Rugged::Commit] commit A commit to traverse.
  # @yield [path, blob] The operation to perform on each blob found. Throw
  #   `:prune` to skip processing any further blobs under the current tree.
  # @yieldparam [String] path The path to a blob, with leading slash.
  # @yieldparam [Rugged::Blob] blob A blob in the commit.

  def traverse(commit, &block)
    import_tree commit.tree, &block
  end

  private

  def import_tree(tree, &block)
    catch :prune do
      tree.walk_blobs do |root, entry|
        block.("/#{root}#{entry[:name]}", entry)
      end
    end
  end
end
