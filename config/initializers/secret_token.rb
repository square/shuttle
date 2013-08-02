# Be sure to restart your server when you modify this file.

# Your secret key is used for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!

# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.
# You can use `rake secret` to generate a secure secret key.

# Make sure your secret_key_base is kept private
# if you're sharing your code publicly.
Shuttle::Application.config.secret_key_base = if Rails.env.production?
                                                File.read(Rails.root.join('data', 'secret_token')).chomp
                                              else
                                                '4d65f0b15c31d7cf3e57541c275a45c1d078634c28c1c5e54b75fae340a872f3e9f92a89e71c9f6015fa71a20337e02bafc0146043c2202b54628319417f98fa'
                                              end
