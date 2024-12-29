//
//  AuthService.swift
//  oneIT
//
//  Created by ALI MUSA ALHASHIM on 23-12-2024.
//

import Foundation


// MARK: - Models
struct LoginRequest: Codable {
    let badgeNumber: String
    let password: String
}

struct LoginResponse: Codable {
    let message: String?
    let badgeNumber: String?
}

class AuthService {
    static let shared = AuthService()
    
    private var sessionId: String?
    private let defaults = UserDefaults.standard
    
    private init() {
        sessionId = defaults.string(forKey: "JSESSIONID")
    }
    
    func getSessionId() -> String? {
        return sessionId
    }
    
    func saveSessionId(from response: HTTPURLResponse, for url: URL) {
        if let headerFields = response.allHeaderFields as? [String: String] {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
            for cookie in cookies {
                if cookie.name == "JSESSIONID" {
                    self.sessionId = cookie.value
                    defaults.set(cookie.value, forKey: "JSESSIONID")
                    print("Saved session ID: \(cookie.value)")
                }
            }
        }
    }
    
    func clearSession() {
        sessionId = nil
        defaults.removeObject(forKey: "JSESSIONID")
    }
}
