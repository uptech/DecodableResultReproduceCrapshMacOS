//
//  ContentView.swift
//  DecodableResultReproduceCrapshMacOS
//
//  Created by Drew De Ponte on 9/30/23.
//

import SwiftUI

import Foundation

extension Result: Decodable where Success: Decodable, Failure == DecodingError {
    public init(from decoder: Decoder) throws {
        do {
            let container = try decoder.singleValueContainer()
            self = .success(try container.decode(Success.self))
        } catch let err as Failure {
            self = .failure(err)
        }
    }
}

public struct BitbucketPaginatedResponse<T: Decodable>: Decodable {
    public let page: Int?
    public let size: Int?
    public let pagelen: Int
    public let next: String?
    public let previous: String?
    public let values: [T]
}

// Note: This is a non-generic version of the struct that if uncommented and substituted in
// place of the above in the decode() call it won't crash.
//public struct BitbucketPaginatedResponseNonGeneric: Decodable {
//    public let page: Int?
//    public let size: Int?
//    public let pagelen: Int
//    public let next: String?
//    public let previous: String?
//    public let values: [Result<String, DecodingError>]
//}

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Button {
                let jsonString = "{\"values\": [], \"pagelen\": 10, \"size\": 0, \"page\": 1}"
                let data = jsonString.data(using: String.Encoding.utf8)!

                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US")
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSxxx"

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .formatted(formatter)

                // Note: This causes the crash, EXC_BAD_ACCESS (code=1, address=0x0)
                let responsePayload = try! decoder.decode(BitbucketPaginatedResponse<Result<String, DecodingError>>.self, from: data)
                
                // Note: This DOES NOT cause the crash
//                let responsePayload = try! decoder.decode(BitbucketPaginatedResponseNonGeneric.self, from: data)


                print("DREW: Decoded the JSON")
                print(responsePayload)
            } label: {
                Text("Trigger")
            }

        }
        .padding()
    }
}

#Preview {
    ContentView()
}
