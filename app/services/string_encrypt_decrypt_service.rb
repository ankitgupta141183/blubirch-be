class StringEncryptDecryptService

  include ActiveSupport::Concern

  def self.open_ssl_method
    OpenSSL::Cipher.new('AES-256-CBC')
  end

  def self.encrypt_string(input_string, encryption_key = nil)
    encrypted_str = self.encryptor(input_string, encryption_key)
    self.encode(encrypted_str)
  end

  def self.decrypt_string(encrypted_string, decryption_key = nil)
    decoded_str = self.decode(encrypted_string)
    self.decryptor(decoded_str, decryption_key)
  end

  def self.encryptor(input_string, encryption_key = nil)
    cipher = open_ssl_method
    cipher.encrypt
    cipher.key = OpenSSL::Digest::SHA256.new(encryption_key).digest
    cipher.update(input_string) + cipher.final
  end

  def self.decryptor(encrypted_string, decryption_key = nil)
    decipher = open_ssl_method
    decipher.decrypt
    decipher.key = OpenSSL::Digest::SHA256.new(decryption_key).digest
    decipher.update(encrypted_string) + decipher.final
  end

  def self.encode(str)
    return str if str.blank?
    Base64.encode64(str).gsub("\n", '')
  end

  def self.decode(str)
    return str if str.blank?
    Base64.decode64(str)
  end
end