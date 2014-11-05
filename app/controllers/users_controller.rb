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

# Administrative panel where admins can modify User accounts.

class UsersController < ApplicationController
  before_filter :admin_required, except: [:search]
  before_filter :authorize_for_search!, only: [:search]
  before_filter :find_user, except: [:index, :search]

  respond_to :html, except: [:search]
  respond_to :json, only: [:search]

  before_filter(only: :update) do
    fix_empty_arrays [:user, :approved_rfc5646_locales]
  end

  # Displays a list of users.
  #
  # Routes
  # ------
  #
  # * `GET /users`

  def index
    @users = User.order('email ASC')
    respond_with @users
  end

  # Displays a form where a User can be administrated.
  #
  # Routes
  # ------
  #
  # * `GET /users/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                   |
  # |:-----|:------------------|
  # | `id` | The ID of a User. |

  def show
    respond_with @user
  end

  # Modifies a User account.
  #
  # Routes
  # ------
  #
  # * `PATCH /users/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                   |
  # |:-----|:------------------|
  # | `id` | The ID of a User. |

  def update
    if params[:user][:password].blank? && params[:user][:password_confirmation].blank?
      params[:user].delete('password')
      params[:user].delete('password_confirmation')
    end
    @user.update_attributes user_params

    respond_with @user do |format|
      format.html do
        if @user.valid?
          flash[:success] = t('controllers.users.update.success', user: @user.name)
          redirect_to user_url(@user)
        else
          render 'show'
        end
      end
    end
  end

  # Deletes a user account. In general it's preferable to simply deactivate the
  # User (remove his/her role), as it preserves the User's records.
  #
  # Routes
  # ------
  #
  # * `DELETE /users/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                   |
  # |:-----|:------------------|
  # | `id` | The ID of a User. |

  def destroy
    if @user.admin? || @user == current_user
      return redirect_to(user_url, alert: t('controllers.users.destroy.not_allowed'))
    end

    @user.destroy
    flash[:notice] = t('controllers.users.destroy.success', user: @user.name)
    redirect_to users_url
  end

  # Allows an administrator to become another User for purposes of testing that
  # user's capabilities, and browsing the website from their point of view.
  # Administrators cannot "become" other admin users.
  #
  # Routes
  # ------
  #
  # * `POST /users/:id/become`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                   |
  # |:-----|:------------------|
  # | `id` | The ID of a User. |

  def become
    if @user.admin?
      redirect_to user_url(@user), alert: t('controllers.users.become.admin')
    else
      sign_in :user, @user, bypass: true
      redirect_to root_url, flash: {notice: t('controllers.users.become.success', user: @user.name)}
    end
  end

  # Returns the name and email of every user. Only searches in activated users.
  # Main use case is email autofilling in issues.
  #
  # Routes
  # ------
  #
  # * `GET /users/search`
  #

  def search
    table = User.arel_table
    users = User.activated.where(table[:email].matches("%#{params[:query]}%").
                                     or(table[:first_name].matches("%#{params[:query]}%")).
                                     or(table[:last_name].matches("%#{params[:query]}%"))).
        select(:first_name, :last_name, :email).limit(5)

    respond_with nil do |format|
      format.json do
        render json: users.map { |u| { name: u.name, email: u.email } }
      end
    end
  end

  private

  def find_user
    @user = User.find(params[:id])
  end

  def user_params
    # too hard to do this with strong parameters :(
    params[:user].to_hash.slice(*%w(
        first_name last_name role password password_confirmation
        approved_rfc5646_locales
    ))
  end

  # If current user doesn't have search privilige, render nothing.
  def authorize_for_search!
    render nothing: true unless current_user.can_search_users?
  end
end
