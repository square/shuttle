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

$(document).ready () ->

  toggle_active = (element) ->
    element.removeClass("inactive").addClass("active")
  
  toggle_inactive = (element) ->
    element.removeClass("active").addClass("inactive")      

  # Sign up click
  $('a[href="#sign-up"]').click () ->
    display_sign_up(500)

  # Sign in click
  $('a[href="#sign-in"]').click () ->
    display_sign_in(500)

  # Forgot password click 
  $('a[href="#forgot-password"]').click () ->
    display_forgot_password(500)

  cur_block = $('#sign-in')
  cur_height = cur_block.height()
  container_height = $('.ten.columns').height()      
  
  toggle_active($('#sign-in'))
  signin_height = $('#sign-in').height()
  toggle_inactive($('#sign-in'))

  toggle_active($('#sign-up'))
  signup_height = $('#sign-up').height()
  toggle_inactive($('#sign-up'))
  # $('#sign-up').removeClass("active").addClass("inactive")

  toggle_active($('#forgot-password'))
  forgot_password_height = $('#forgot-password').height()
  toggle_inactive($('#forgot-password'))
  # $('#forgot-password').removeClass("active").addClass("inactive")

  toggle_active(cur_block)
  $('.ten.columns').height(container_height)  

  # Display Methods
  display_sign_up = (animate_time) -> 
    cur_block.stop(true, true)
    $(".body-portion").stop(true, true)
    $(".ten.columns").stop(true, true)

    prev_block = cur_block
    cur_block.fadeOut animate_time, () -> 
      prev_block.removeAttr( 'style' )
      toggle_inactive(prev_block)
      $('#sign-up').fadeIn(animate_time).removeAttr( 'style' )
      toggle_active($('#sign-up'))

    $(".body-portion").animate({
      height: $(".body-portion").height() - (cur_height - signup_height)
    }, animate_time * 2)

    $(".ten.columns").animate({
      height: $(".ten.columns").height() - (cur_height - signup_height)
    }, animate_time * 2)
    
    $('.ten.columns h1').fadeOut animate_time, () ->
      $('.ten.columns h1').text("Sign up for Shuttle").fadeIn(animate_time)
    $('.ten.columns p').fadeOut animate_time, () ->
      $('.ten.columns p').text("Website and Application Translation Software").fadeIn(animate_time)

    cur_height = signup_height
    cur_block = $('#sign-up')

  display_sign_in = (animate_time) ->
    cur_block.stop(true, true)
    $(".body-portion").stop(true, true)
    $(".ten.columns").stop(true, true)

    prev_block = cur_block
    cur_block.fadeOut animate_time, () -> 
      prev_block.removeAttr( 'style' )
      toggle_inactive(prev_block)
      $('#sign-in').fadeIn(animate_time).removeAttr( 'style' )
      toggle_active($('#sign-in'))

    $(".body-portion").animate({
      height: $(".body-portion").height() - (cur_height - signin_height)
    }, animate_time * 2)

    $(".ten.columns").animate({
      height: $(".ten.columns").height() - (cur_height - signin_height)
    }, animate_time * 2)
    
    $('.ten.columns h1').fadeOut animate_time, () ->
      $('.ten.columns h1').text("Log in to Shuttle").fadeIn(animate_time)
    $('.ten.columns p').fadeOut animate_time, () ->
      $('.ten.columns p').text("Website and Application Translation Software").fadeIn(animate_time)

    cur_height = signin_height
    cur_block = $('#sign-in')

  display_forgot_password = (animate_time) ->
    cur_block.stop(true, true)
    $(".body-portion").stop(true, true)
    $(".ten.columns").stop(true, true)
    
    prev_block = cur_block
    cur_block.fadeOut animate_time, () -> 
      prev_block.removeAttr( 'style' )
      toggle_inactive(prev_block)
      $('#forgot-password').fadeIn(animate_time).removeAttr( 'style' )
      toggle_active($('#forgot-password'))

    $(".body-portion").animate({
      height: $(".body-portion").height() - (cur_height - forgot_password_height)
    }, animate_time * 2)

    $(".ten.columns").animate({
      height: $(".ten.columns").height() - (cur_height - forgot_password_height)
    }, animate_time * 2)
    
    $('.ten.columns h1').fadeOut animate_time, () ->
      $('.ten.columns h1').text("Forgot your password?").fadeIn(animate_time)
    $('.ten.columns p').fadeOut animate_time, () ->
      $('.ten.columns p').text("Send me reset password instructions").fadeIn(animate_time)

    cur_height = forgot_password_height
    cur_block = $('#forgot-password')

  switch window.location.hash.substr(1) 
    when "sign-up" then display_sign_up(300)
    when "forgot-password" then display_forgot_password(300)
    else 
  # else if window.location.hash.substr(1) == "forgot-password"
    
