import Cocoa
import FlutterMacOS

import AppKit
import Contacts

enum ContactField {
  // Name-related
  case displayName
  case namePrefix
  case givenName
  case middleName
  case familyName
  case nameSuffix

  // Organization-related
  case company
  case department
  case jobDescription

  // Phone-related
  case phoneNumbers
  case phoneLabels

  // Email-related
  case emailAddresses
  case emailLabels
}

private func parseContactField(field: String) throws -> ContactField {
  switch field {
  case "displayName":
    return .displayName
  case "namePrefix":
    return .namePrefix
  case "givenName":
    return .givenName
  case "middleName":
    return .middleName
  case "familyName":
    return .familyName
  case "nameSuffix":
    return .nameSuffix
  case "company":
    return .company
  case "department":
    return .department
  case "jobDescription":
    return .jobDescription
  case "phoneNumbers":
    return .phoneNumbers
  case "phoneLabels":
    return .phoneLabels
  case "emailAddresses":
    return .emailAddresses
  case "emailLabels":
    return .emailLabels
  default:
    throw NSError(domain: "Invalid field", code: 0, userInfo: nil)
  }
}

private func getContactFieldKeyDescriptors(field: ContactField) -> [CNKeyDescriptor] {
    switch (field) {
    case .displayName:
        return [CNContactGivenNameKey, CNContactFamilyNameKey] as [CNKeyDescriptor]
    case .namePrefix:
        return [CNContactNamePrefixKey] as [CNKeyDescriptor]
    case .givenName:
        return [CNContactGivenNameKey] as [CNKeyDescriptor]
    case .middleName:
        return [CNContactMiddleNameKey] as [CNKeyDescriptor]
    case .familyName:
        return [CNContactFamilyNameKey] as [CNKeyDescriptor]
    case .nameSuffix:
        return [CNContactNameSuffixKey] as [CNKeyDescriptor]
    case .company:
        return [CNContactOrganizationNameKey] as [CNKeyDescriptor]
    case .department:
        return [CNContactDepartmentNameKey] as [CNKeyDescriptor]
    case .jobDescription:
        return [CNContactJobTitleKey] as [CNKeyDescriptor]
    case .phoneNumbers:
        return [CNContactPhoneNumbersKey] as [CNKeyDescriptor]
    case .phoneLabels:
        return [CNContactPhoneNumbersKey] as [CNKeyDescriptor]
    case .emailAddresses:
        return [CNContactEmailAddressesKey] as [CNKeyDescriptor]
    case .emailLabels:
        return [CNContactEmailAddressesKey] as [CNKeyDescriptor]
    }
}

@available(iOS 9.0, *)
public class FastContactsPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.github.s0nerik.fast_contacts", binaryMessenger: registrar.messenger)
        let instance = FastContactsPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private var allContacts = [Dictionary<String, Any?>]()

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "fetchAllContacts":
            let args = call.arguments as! Dictionary<String, Any>
            let fields = Set((args["fields"] as! [String]).map { try! parseContactField(field: $0) })

            DispatchQueue.global().async {
                let start = DispatchTime.now()

                let contacts = self.getContacts(fields: fields)

                let end = DispatchTime.now()
                let timeMillis = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000

                self.allContacts = contacts
                DispatchQueue.main.async {
                    result([
                        "count": contacts.count,
                        "timeMillis": timeMillis,
                    ])
                }
            }
        case "getAllContactsPage":
            let args = call.arguments as! Dictionary<String, Int>
            let from = args["from"]!
            let to = args["to"]!

            let pageJson = Array(allContacts[from..<to])
            let compactedPageJson = compactJSON(pageJson)
            result(compactedPageJson)
        case "clearFetchedContacts":
            allContacts.removeAll()
            result(nil)
        case "getContactImage":
            let args = call.arguments as! Dictionary<String, String>
            let id = args["id"]!
            let size = args["size"]!

DispatchQueue.global().async {
        self.getContactImage(contactId: id, size: size) { imageResult in
            DispatchQueue.main.async {
                result(imageResult)
            }
        }
    }
        case "getContact":
            let args = call.arguments as! Dictionary<String, Any>
            let id = args["id"]! as! String
            let fields = Set((args["fields"] as! [String]).map { try! parseContactField(field: $0) })

            DispatchQueue.global().async {
                let contacts = self.getContacts(fields: fields, contactId: id)
                DispatchQueue.main.async {
                    if (contacts.count > 0) {
                        result(contacts[0])
                    } else {
                        result(nil)
                    }
                }
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func getContacts(fields: Set<ContactField>, contactId: String? = nil) -> Array<Dictionary<String, Any?>> {

        let contactStore = CNContactStore()

        var result = [Dictionary<String, Any?>]()

requestAccessToContacts { accessGranted in

if accessGranted {

        let keys = fields.map(getContactFieldKeyDescriptors).flatMap { $0 }
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = CNContactSortOrder.none

        if let contactId = contactId {
            request.predicate = CNContact.predicateForContacts(withIdentifiers: [contactId])
        }

        try? contactStore.enumerateContacts(with: request) { (contact, cursor) in
            result.append(
                Contact(fromContact: contact, fields: fields).toMap()
            )
        }
        } else {
   // test
    }

    }
        return result
    }

private func getContactImage(contactId: String, size: String, result: @escaping FlutterResult) {
    let contactStore = CNContactStore()

    requestAccessToContacts { accessGranted in
        if accessGranted {
            do {
                let keysToFetch = size == "thumbnail" ? [CNContactThumbnailImageDataKey] as [CNKeyDescriptor] : [CNContactImageDataAvailableKey, CNContactImageDataKey] as [CNKeyDescriptor]
                let contact = try contactStore.unifiedContact(withIdentifier: contactId, keysToFetch: keysToFetch)

                let data = size == "thumbnail" ? contact.thumbnailImageData : contact.imageData
                if let data = data {
                    result(FlutterStandardTypedData.init(bytes: data))
                } else {
                    result(nil)
                }
            } catch {
                print("Error fetching contact: \(error)")
                result(nil) // Handle the error appropriately
            }
        } else {
            result(nil) // Access not granted
        }
    }
}
}

// Returns compacted JSON value:
// - removes empty arrays
// - removes empty objects
// - removes null values
// - removes empty strings
private func compactJSON(_ json: Any) -> Any {
    switch json {
    case let dict as [String: Any]:
        var result = [String: Any]()
        for (key, value) in dict {
            let compactedValue = compactJSON(value)
            if compactedValue is NSNull {
                continue
            }
            result[key] = compactedValue
        }
        if (result.isEmpty) {
            return NSNull()
        }
        return result
    case let array as [Any]:
        return [Any](array.map(compactJSON).filter { $0 is NSNull == false })
    case let string as String:
        return string.isEmpty ? NSNull() : string
    default:
        return json
    }
}

private func requestAccessToContacts(completion: @escaping (Bool) -> Void) {
    let contactStore = CNContactStore()

    contactStore.requestAccess(for: .contacts) { (accessGranted, error) in
        if let error = error {
            print("Error requesting access to contacts: \(error)")
            completion(false)
            return
        }
        completion(accessGranted)
    }
}

/*
 *                if !isGranted || err != nil {
 *                    result(nil)
 *                    return
 *                }
 *
 *                guard (CNContactStore.authorizationStatus(for: .contacts) == .notDetermined || CNContactStore.authorizationStatus(for: .contacts) == .authorized) else {
 *                    result(nil)
 *                    return
 *                }
 */
