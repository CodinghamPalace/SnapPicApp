//
//  SnapPicTests.swift
//  SnapPicTests
//
//  Created by STUDENT on 8/28/25.
//

import Testing
@testable import SnapPic

struct SnapPicTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func validEmailAddresses() throws {
        let vm = AuthViewModel()
        for email in ["a@b.co", "user.name+tag@domain.io", "USER@EXAMPLE.ORG"] {
            #expect(vm.validateEmail(email))
        }
    }

    @Test func invalidEmailAddresses() throws {
        let vm = AuthViewModel()
        for email in ["", "plainaddress", "user@", "user@domain", "user@domain."] {
            #expect(vm.validateEmail(email) == false)
        }
    }
}
