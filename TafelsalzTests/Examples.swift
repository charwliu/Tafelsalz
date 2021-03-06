import XCTest

import Tafelsalz

class Examples: XCTestCase {

	func testSymmetricEncryptionWithEphemeralKeys() {
		let secretBox = SecretBox()
		let plaintext = "Hello, World!".utf8Bytes
		let ciphertext = secretBox.encrypt(plaintext: plaintext)
		let decrypted = secretBox.decrypt(ciphertext: ciphertext)!

		XCTAssertEqual(decrypted, plaintext)
	}

	func testSymmetricEncryptionWithPersistedKeys() {
		// Create a persona
		let alice = Persona(uniqueName: "Alice")

		// Once a secret of that persona is used, it will be persisted in the
		// system's Keychain.
		let secretBox = SecretBox(persona: alice)!

		// Use your SecretBox as usual
		let plaintext = "Hello, World!".utf8Bytes
		let ciphertext = secretBox.encrypt(plaintext: plaintext)
		let decrypted = secretBox.decrypt(ciphertext: ciphertext)!

		// Forget the persona and remove all related Keychain entries
		try! Persona.forget(alice)

		XCTAssertEqual(decrypted, plaintext)
	}

	func testSymmetricEncryptionWithPadding() {
		let secretBox = SecretBox()
		let plaintext = "Hello, World!".utf8Bytes
		let padding: Padding = .padded(blockSize: 16)
		let ciphertext = secretBox.encrypt(plaintext: plaintext, padding: padding)
		let decrypted = secretBox.decrypt(ciphertext: ciphertext, padding: padding)!

		XCTAssertEqual(decrypted, plaintext)
	}

	func testPasswordHashing() {
		let password = Password("Correct Horse Battery Staple")!
		let hashedPassword = password.hash()!

		// Store `hashedPassword.string` to database.

		// If a user wants to authenticate, just read it from the database and
		// verify it against the password given by the user.
		if hashedPassword.isVerified(by: password) {
			// The user is authenticated successfully.
		}
	}

	func testPublicGenericHashing() {
		let data = "Hello, World!".utf8Bytes
		let hash = GenericHash(bytes: data)

		XCTAssertNotNil(hash)
	}

	func testPrivateGenericHashingWithPersistedKeys() {
		// Create a persona
		let alice = Persona(uniqueName: "Alice")

		// Generate a personalized hash for that persona
		let data = "Hello, World!".utf8Bytes
		let hash = GenericHash(bytes: data, for: alice)

		// Forget the persona and remove all related Keychain entries
		try! Persona.forget(alice)

		XCTAssertNotNil(hash)
	}

	func testMasterKeyBasedKeyDerivation() {
		let context = MasterKey.Context("Examples")!
		let masterKey = MasterKey()
		let subKey1 = masterKey.derive(sizeInBytes: MasterKey.DerivedKey.MinimumSizeInBytes, with: 0, and: context)!
		let subKey2 = masterKey.derive(sizeInBytes: MasterKey.DerivedKey.MinimumSizeInBytes, with: 1, and: context)!

		// You can also derive a key in order to use it with secret boxes
		let secretBox = SecretBox(secretKey: masterKey.derive(with: 0, and: context))

		KMAssertNotEqual(subKey1, subKey2)
		XCTAssertNotNil(secretBox)
	}

	func testPasswordBasedKeyDerivation() {
		let plaintext = "Hello, World!".utf8Bytes
		let password = Password("Correct Horse Battery Staple")!

		// Derive a new key from a password
		let derivedKey1 = password.derive(sizeInBytes: SecretBox.SecretKey.SizeInBytes)!
		let secretBox1 = SecretBox(secretKey: SecretBox.SecretKey(derivedKey1))
		let ciphertext = derivedKey1.publicParameters + secretBox1.encrypt(plaintext: plaintext).bytes

		// Derive a previously generated key from a password
		let (salt, complexity, memory) = Password.DerivedKey.extractPublicParameters(bytes: ciphertext)!
		let derivedKey2 = password.derive(sizeInBytes: SecretBox.SecretKey.SizeInBytes, complexity: complexity, memory: memory, salt: salt)!
		let secretBox2 = SecretBox(secretKey: SecretBox.SecretKey(derivedKey2))
		let authenticatedCiphertextBytes = Bytes(ciphertext[Int(Password.DerivedKey.SizeOfPublicParametersInBytes)...])
		let authenticatedCiphertext = SecretBox.AuthenticatedCiphertext(bytes: authenticatedCiphertextBytes)!
		let decrypted = secretBox2.decrypt(ciphertext: authenticatedCiphertext)!

		XCTAssertEqual(decrypted, plaintext)
	}

	func testKeyExchange() {
		let alice = KeyExchange(side: .client)
		let bob = KeyExchange(side: .server)

		let alicesSessionKey = alice.sessionKey(for: bob.publicKey)
		let bobsSessionKey = bob.sessionKey(for: alice.publicKey)

		// alicesSessionKey == bobsSessionKey

		KMAssertEqual(alicesSessionKey!, bobsSessionKey!)
	}
}
