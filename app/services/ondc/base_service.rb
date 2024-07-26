class Ondc::BaseService
  
  def create_order_history(order_id, order_state)
    OndcOrderHistory.create!({ondc_order_id: order_id, order_state: order_state, history_date: Date.current})
  end

  #& Generating signing_public_key
  #^ signing_key = RbNaCl::SigningKey.generate
  #^ signing_key.to_s
  #^ signature = signing_key.sign('blubirch.in')
  #^ enc_code = Base64.encode64(signature) Encryption
  #? => llaSyGXgt4JboEwlrIwJhBLKQAqJDBfB/hLG+ydPknZuYgkT1xD5QdWCCjYV\nFvHnFZp9gIbMPxUSBNOlt+ceAw==\n
  #^ Base64.encode64(enc_code)
  #? => 'blubirch.com'

  #& Generating encryption_public_key
  #^ private_key = RbNaCl::PrivateKey.generate
  #^ public_key  = private_key.public_key
  #^ box = RbNaCl::Box.new(public_key, private_key)
  #^ nonce = RbNaCl::Random.random_bytes(box.nonce_bytes)
  #^ message = 'blubirch.in'
  #^ ciphertext = box.encrypt(nonce, message)
  #^ enc_code = Base64.encode64(ciphertext) Encryption
  #? => Yu4HR9mPT1bHxQr2PXC4IRNChtgr5nQqn7MfYg==\n
  #^ decrypted_message = box.decrypt(nonce, ciphertext)
  #? => "blubirch.com"

  #! REGISTRY STEPS
  
  #& STEP 1
  # gem install rbnacl
  # require 'rbnacl'
  # signing_key = RbNaCl::SigningKey.generate

  # signing_public_key = signing_key.verify_key.to_bytes
  # signing_private_key = signing_key.to_bytes

  # signing_public_key_base64 = Base64.encode64(signing_public_key)
  # signing_private_key_base64 = Base64.encode64(signing_private_key)

  #& Step 2
  # require 'rbnacl'
  # require 'base64'

  # encryption_key = RbNaCl::PrivateKey.generate

  # encryption_private_key = encryption_key.to_bytes

  # encryption_private_key_base64 = Base64.encode64(encryption_private_key)

  #& Step 3
  # require 'securerandom'

  # request_id = SecureRandom.uuid


  #& Step 4
  # require 'rbnacl'

  # signing_private_key = RbNaCl::SigningKey.new(Base64.decode64(signing_private_key_base64))

  # signature = signing_private_key.sign(request_id)

  # signed_unique_req_id = Base64.encode64(signature)

end