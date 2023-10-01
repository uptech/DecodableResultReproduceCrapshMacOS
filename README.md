# macOS Sonoma (14.0) & generic struct with `JSONDecoder` = crash

This repository holds a small sample project to reproduce a crash that we were
experiencing in our app, [Pullwalla](https://pullwalla.com) after the macOS
Sonoma (14.0) upgrade.

## Background & Details

We have an application, [Pullwalla](https://pullwalla.com), that has run fine
on macOS until the most recent version, macOS Sonoma (14.0). Any users that
upgraded their operating system to Sonoma 14.0 and had a Bitbucket Cloud
connection enabled would experience the app crashing. Specifically they would
experience a `EXC_BAD_ACCESS (code=1, address=0x0)` causing the application to
crash.

Normally, this has been an issue with trying to access a memory address that is
null. So, I started the hunt through the code trying to figure out what was
going on. But, I wasn't able to find any objects that were freed, but we were
still accessing, etc.

Over a few days of trial error and experimentation around the crash area I was
able to narrow it down to decoding with `JSONDecoder` and a generic struct. In
our case we have the following to allow us to decode paginated results from
Bitbucket.

```swift
public struct BitbucketPaginatedResponse<T: Decodable>: Decodable {
    public let page: Int?
    public let size: Int?
    public let pagelen: Int
    public let next: String?
    public let previous: String?
    public let values: [T]
}
```

In this particular case we are using that struct similar to the following
example that facilitates reproducing the crash.

```swift
let jsonString = "{\"values\": [], \"pagelen\": 10, \"size\": 0, \"page\": 1}"
let data = jsonString.data(using: String.Encoding.utf8)!

let formatter = DateFormatter()
formatter.locale = Locale(identifier: "en_US")
formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSxxx"

let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .formatted(formatter)

// Note: This causes the crash, EXC_BAD_ACCESS (code=1, address=0x0)
let responsePayload = try! decoder.decode(BitbucketPaginatedResponse<Result<String, DecodingError>>.self, from: data)
```

You might be thinking to yourself, "Wait you are using a `Result` type in
decoding." Yep, this is facilitated by the following `extension`.

```swift
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
```

When running in Xcode with the debugger we can see that the crash is related to
the `decoder.decode()` call.

![alt text](https://github.com/uptech/DecodableResultReproduceCrapshMacOS/blob/main/screenshots/crash_stack_trace.png?raw=true)

![alt text](https://github.com/uptech/DecodableResultReproduceCrapshMacOS/blob/main/screenshots/line_code_highlighted_when_crashed.png?raw=true)


But the interesting thing is that the crash only happens when I am asking it to
decode `BitbucketPaginatedResponse<T>`. If we create a non-generic version of
this struct called `BitbucketPaginatedResponseNonGeneric` as follows then it
won't crash.

```swift
public struct BitbucketPaginatedResponseNonGeneric: Decodable {
    public let page: Int?
    public let size: Int?
    public let pagelen: Int
    public let next: String?
    public let previous: String?
    public let values: [Result<String, DecodingError>]
}
```

This doesn't really help our situation in terms of a work around as the
pagination pattern in Bitbucket's payloads is a generic pattern. So we really
need the generic to work again with `decode()`. But at least it helps give us
some more confidence that the issue is actually with the fact that the struct
is generic.

Also, in the stack trace when the crash occurs the next step up is related to
the witness table. This makes me think that part of the dynamic dispatch and
looking up of the method is failing and causing the crash.

![alt text](https://github.com/uptech/DecodableResultReproduceCrapshMacOS/blob/main/screenshots/witness_table_stack_step.png?raw=true)

![alt text](https://github.com/uptech/DecodableResultReproduceCrapshMacOS/blob/main/screenshots/getTypeContextDescriptor_stack_step.png?raw=true)

