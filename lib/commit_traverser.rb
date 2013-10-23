# Mixin that adds the ability to traverse the blobs of a `Git::Object::Commit`.

module CommitTraverser

  # Recursively scans the trees of a commit, locating and yielding blobs. Will
  # run indefinitely if there are cycles in the tree graph.
  #
  # @param [Git::Object::Commit] commit A commit to traverse.
  # @yield [path, blob] The operation to perform on each blob found.
  # @yieldparam [String] path The path to a blob, with leading slash.
  # @yieldparam [Git::Object::Blob] blob A blob in the commit.

  def traverse(commit, &block)
    import_tree commit.gtree, '', &block
  end

  private

  def import_tree(tree, path, &block)
    tree.blobs.each do |name, blob|
      blob_path = "#{path}/#{name}"
      block.(blob_path, blob)
    end

    tree.trees.each do |name, subtree|
      import_tree subtree, "#{path}/#{name}", &block
    end
  end
end
