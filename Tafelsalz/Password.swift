import libsodium

/**
	This class can be used to securely handle passwords. Passwords will be
	copied to a secure memory location, comparison will be performed in constant
	time to avoid timing attacks and a method for hashing passwords is provided
	to store them for user authentication purposes.
*/
public class Password {

	/**
		Defines how much CPU load will be required for hashing a password. This
		reduces the speed of brute-force attacks. You might be required to chose
		`high` or `medium` if your device does not have much CPU power.

		- see: [Guidelines for choosing the parameters](https://download.libsodium.org/doc/password_hashing/the_argon2i_function.html#guidelines-for-choosing-the-parameters)
	*/
	public enum ComplexityLimit {
		/**
			This is the fastest option and should be avoided if possible.

			- see: [`libsodium` documentation](https://download.libsodium.org/doc/password_hashing/the_argon2i_function.html#key-derivation)
		*/
		case medium

		/**
			This takes about 0.7 seconds on a 2.8 Ghz Core i7 CPU.

			- see: [`libsodium` documentation](https://download.libsodium.org/doc/password_hashing/the_argon2i_function.html#key-derivation)
		*/
		case high

		/**
			This takes about 3.5 seconds on a 2.8 Ghz Core i7 CPU.

			- see: [`libsodium` documentation](https://download.libsodium.org/doc/password_hashing/the_argon2i_function.html#key-derivation)
		*/
		case veryHigh
	}

	/**
		Defines how much memory will be required for hashing a password. This
		makes brute-forcing more costly. The speed requirements induced by
		increased CPU load can be reduced by massively parallelizing the attack
		using FPGAs. As these have limited memory, this factor mitigates those
		attacks. You might be required to chose `high` or `medium` if your
		device is not equipped with much memory.

		- see: [Guidelines for choosing the parameters](https://download.libsodium.org/doc/password_hashing/the_argon2i_function.html#guidelines-for-choosing-the-parameters)
	*/
	public enum MemoryLimit {
		/**
			This requires about 32 MiB memory.

			- see: [`libsodium` documentation](https://download.libsodium.org/doc/password_hashing/the_argon2i_function.html#key-derivation)
		*/
		case medium

		/**
			This requires about 128 MiB memory.

			- see: [`libsodium` documentation](https://download.libsodium.org/doc/password_hashing/the_argon2i_function.html#key-derivation)
		*/
		case high

		/**
			This requires about 512 MiB memory.

			- see: [`libsodium` documentation](https://download.libsodium.org/doc/password_hashing/the_argon2i_function.html#key-derivation)
		*/
		case veryHigh
	}

	/**
		Helper function to translate the `ComplexityLimit` enum to the values
		expected by `libsodium`.

		- parameters:
			- value: The complexity limit that should be translated.

		- returns: The complexity limit that can be interpreted by `libsodium`.
	*/
	private static func sodiumValue(_ value: ComplexityLimit) -> Int {
		switch value {
			case .medium:
				return libsodium.crypto_pwhash_opslimit_interactive()
			case .high:
				return libsodium.crypto_pwhash_opslimit_moderate()
			case .veryHigh:
				return libsodium.crypto_pwhash_opslimit_sensitive()
		}
	}

	/**
		Helper function to translate the `MemoryLimit` enum to the values
		expected by `libsodium`.

		- parameters:
			- value: The memory limit that should be translated.

		- returns: The memory limit that can be interpreted by `libsodium`.
	*/
	private static func sodiumValue(_ value: MemoryLimit) -> Int {
		switch value {
		case .medium:
			return libsodium.crypto_pwhash_memlimit_interactive()
		case .high:
			return libsodium.crypto_pwhash_memlimit_moderate()
		case .veryHigh:
			return libsodium.crypto_pwhash_memlimit_sensitive()
		}
	}

	/**
		The password bytes in secure memory.
	*/
	let bytes: KeyMaterial

	/**
		The password size in bytes.
	*/
	var sizeInBytes: PInt {
		get {
			return bytes.sizeInBytes
		}
	}

	/**
		Initializes a password from a given string with a given encoding.

		- parameters:
			- password: The password string, e.g., as entered by the user.
			- encoding: The encoding of the `password` string.
	*/
	public init?(_ password: String, using encoding: String.Encoding = .utf8) {
		guard var passwordBytes = password.data(using: encoding) else {
			// Invalid encoding
			return nil
		}

		guard let bytes = KeyMaterial(bytes: &passwordBytes) else {
			return nil
		}

		self.bytes = bytes
	}

	/**
		Hashes a password for securely storing it on disk or in a database for
		the purpose of authenticating a user.

		- warning: Do not change the complexity limits unless it is required,
			due to device limits or negative performance impact. Please refer to
			the [Guidelines for choosing the parameters](https://download.libsodium.org/doc/password_hashing/the_argon2i_function.html#guidelines-for-choosing-the-parameters).

		- parameters:
			- complexity: The CPU load required.
			- memory: The amount of memory required.

		- returns: The hashed password, `nil` if something went wrong.

		- see: `HashedPassword`
	*/
	public func hash(complexity: ComplexityLimit = .high, memory: MemoryLimit = .high) -> HashedPassword? {
		var hashedPasswordBytes = Data(count: Int(HashedPassword.SizeInBytes))

		let successfullyHashed = hashedPasswordBytes.withUnsafeMutableBytes {
			hashedPasswordBytesPtr in

			return bytes.withUnsafeBytes {
				passwordBytesPtr in

				return libsodium.crypto_pwhash_str(
					hashedPasswordBytesPtr,
					passwordBytesPtr,
					UInt64(sizeInBytes),
					UInt64(Password.sodiumValue(complexity)),
					Password.sodiumValue(memory)
				) == 0
			}
		}

		guard successfullyHashed else {
			return nil
		}

		return HashedPassword(hashedPasswordBytes)
	}

	/**
		Checks if this password authenticates a hashed password.

		- parameters:
			- hashedPassword: The hashed password.

		- returns: `true` if this password authenticates the hashed password.

		- see: `HashedPassword.isVerified(by:)`
	*/
	public func verifies(_ hashedPassword: HashedPassword) -> Bool {
		return bytes.withUnsafeBytes {
			bytesPtr in

			return hashedPassword.bytes.withUnsafeBytes {
				hashedPasswordBytesPtr in

				return libsodium.crypto_pwhash_str_verify(
					hashedPasswordBytesPtr,
					bytesPtr,
					UInt64(sizeInBytes)
				) == 0
			}
		}
	}
}

extension Password: Equatable {
	/**
		Compares two passwords in constant time regardless of their length. This
		is done by calculating a hash (in sense of a fingerprint not in sense of
		a hashed password used for storage) on the password and comparing the
		hash values (which are of equal length) in constant time.

		- parameters:
			- lhs: A password.
			- rhs: Another password.

		- returns: `true` if the passwords are equal.
	*/
	public static func ==(lhs: Password, rhs: Password) -> Bool {
		return lhs.bytes.isFingerprintEqual(to: rhs.bytes)
	}
}