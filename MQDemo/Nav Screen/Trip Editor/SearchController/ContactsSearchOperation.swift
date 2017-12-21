//
//  ContactsSearchOperation.swift
//  MQNavigationDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import UIKit
import Contacts
import MQCore

class ContactsSearchOperation: SearchOperation {
    
    static var store = CNContactStore()
    fileprivate let semaphore = DispatchSemaphore(value: 0)

    override func main() {
        
        checkAccessStatus { [weak self] success in
            
            guard let strongSelf = self else { return }

            var newDestinations = [Destination]()
            defer {
                strongSelf.semaphore.signal()
                strongSelf.completion(newDestinations)
            }
            
            let predicate = CNContact.predicateForContacts(matchingName: strongSelf.searchText)
            
            do{
                
                let toFetch = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName), CNContactPostalAddressesKey] as! [CNKeyDescriptor]
                let contacts = try ContactsSearchOperation.store.unifiedContacts(matching: predicate, keysToFetch: toFetch)
                
                guard contacts.count > 0  else {
                    return
                }
                
                let nameFormatter = CNContactFormatter()
                let addressFormatter = CNPostalAddressFormatter()
                
                contacts.forEach { contact in
                    guard contact.isKeyAvailable(CNContactPostalAddressesKey), contact.postalAddresses.isEmpty == false else { return }

                    func convert(_ address: CNPostalAddress) -> MQGeoAddress {
                        let newAddress = MQGeoAddress()
                        newAddress.street = address.street
                        newAddress.city = address.city
                        newAddress.state = address.state
                        newAddress.zip = address.postalCode
                        newAddress.country = address.country
                        newAddress.geoQuality = .MQGQAddress
                        return newAddress
                    }
                    
                    let name = nameFormatter.string(from: contact)
                    for address in contact.postalAddresses {
                        let formattedAddress = addressFormatter.string(from: address.value).components(separatedBy: .newlines).joined(separator: ", ")
                        guard let destination = Destination(geoAddress: convert(address.value)) else { continue }
                        destination.displayTitle = name ?? ""
                        destination.displaySubtitle = formattedAddress
                        destination.favoriteType = .contact
                        newDestinations.append( destination )
                    }
                }
                
            }catch let err{
                print(err)
            }
        }
        
        // Don't let the operation close without the asynchronous calls finishing
        _ = semaphore.wait(timeout: .now() + 10)
    }
    
    func checkAccessStatus(completionHandler: @escaping (_ accessGranted: Bool) -> Void) {
        let authorizationStatus = CNContactStore.authorizationStatus(for: CNEntityType.contacts)
        
        switch authorizationStatus {
        case .authorized:
            completionHandler(true)
        case .denied, .notDetermined:
            ContactsSearchOperation.store.requestAccess(for: .contacts, completionHandler: { (access, accessError) in
                if access {
                    completionHandler(access)
                }
            })
        default:
            completionHandler(false)
        }
    }
}
