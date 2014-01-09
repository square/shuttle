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

# Adds the {#git_object_field} method to models.
#
# @example
#   class Model < ActiveRecord::Base
#     extend GitObjectField
#     git_object_field :my_field, git_type: :any
#   end

module GitObjectField
  include ShaField

  # @overload git_object_field(field, ..., options={})
  #   Specifies that the field(s) represent the SHA2 identifiers of objects in a
  #   Git repository. See the {ShaField} module for more information about how
  #   SHA2 values are stored and accessed, and additional options that can be
  #   passed to this method.
  #
  #   An attribute is added to the model called `skip_sha_check`. When set, the
  #   SHA is not tested for existence in the Git repository. This can
  #   potentially save a connection to the remote repository.
  #
  #   @param [Symbol] field The name of a `BYTEA` column to treat as a SHA2
  #     value.
  #   @param [Hash] options Additional options.
  #   @option options [Symbol] git_type If set, the value is assumed to be a Git
  #     object of this type. Valid values are `:commit`, `:tag`, `:blob`,
  #     `:tree`, and `:any`.
  #   @option options [Git::Repository, #call] repo (&:repo) If `git_type` is
  #     set, this must either be a repository to validate SHA2s with, or a Proc
  #     that is passed an instance of this model and returns a repository.

  def git_object_field(*fields)
    options = fields.extract_options!

    git_type = options.delete(:git_type) || raise(ArgumentError, "Must set :git_type option when using git_option_field")
    raise ArgumentError, "Unknown value for git_type" unless [:tree, :blob, :commit, :tag, :any].include?(git_type)
    repo            = options.delete(:repo) || :repo.to_proc
    repo_must_exist = options.delete(:repo_must_exist)

    attr_accessor :skip_sha_check

    fields.each do |field|
      validate(on: :create, unless: :skip_sha_check) do |object|
        repo_to_use = repo.respond_to?(:call) ? repo.(object) : repo

        unless repo_to_use
          if repo_must_exist
            raise ActiveRecord::RecordNotSaved, "Could not access repository for #{object.inspect}"
          else
            return
          end
        end

        git_object = repo_to_use.object(send(field))

        unless git_object
          object.errors.add field, :unknown_sha
          return
        end

        case git_type
          when :commit then
            object.errors.add(field, :wrong_sha_type) unless git_object.commit?
          when :tag then
            object.errors.add(field, :wrong_sha_type) unless git_object.tag?
          when :tree then
            object.errors.add(field, :wrong_sha_type) unless git_object.tree?
          when :blob then
            object.errors.add(field, :wrong_sha_type) unless git_object.blob?
        end
      end
    end

    fields << options
    sha_field *fields
  end
end
