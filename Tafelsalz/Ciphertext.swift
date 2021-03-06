/**
	A ciphertext is an ecrypted message. In contrast to `EncryptedData` it only
	contains the encrypted message, while `EncryptedData` might contain other
	information as well, such as a message authentication code et cetera.
*/
public struct Ciphertext: EncryptedData {

	/**
		The encrypted message.
	*/
	public let bytes: Bytes

	/**
		The size of the encrypted message in bytes.
	*/
	public var sizeInBytes: UInt32 {
		return UInt32(bytes.count)
	}

	/**
		Constructs a `Ciphertext` instance from bytes.

		- note:
			The bytes passed to this functions must be encrypted already. This
			does not encrypt the bytes, use `SecretBox` or similar for that.
	*/
	public init(_ bytes: Bytes) {
		self.bytes = bytes
	}
}
