// MARK: - Enterprise Business Rules

struct Contact {
    let street: String
    let city: String
    let state: String
    let country: String?
}

struct ContactViewModel {
    let fullAddress: String
}

enum ContactError: Error {
    case notAccessible
    case 💣
}

// MARK: - Application Business Rules

extension Result {
    func onSucces(_ fn: (Success) -> ()) {
        guard case let .success(value) = self else { return }
        fn(value)
    }
    func onFailure(_ fn: (Failure) -> ()) {
        guard case let .failure(error) = self else { return }
        fn(error)
    }
}

protocol ValidContractsInteractable {
    func all()
}

final class ValidContractsInteractor: ValidContractsInteractable {
    private let gateway: ContactsGateway
    private let presenter: ContactsPresenter

    init(gateway: ContactsGateway, presenter: ContactsPresenter) {
        self.gateway = gateway
        self.presenter = presenter
    }

    func all() {
        gateway.all { [weak self] result in
            guard let strongSelf = self else { return }
            result.onFailure(strongSelf.presenter.failed)
            result.onSucces { allContacts in
                let validContacts = allContacts.filter { $0.country != nil }
                strongSelf.presenter.finded(contacts: validContacts)
            }
        }
    }
}

// MARK: - Interface adapters

protocol ContactsGateway {
    func all(_ completionHandler: (Result<[Contact], ContactError>) -> Void)
}

final class ContactsNativeGateway: ContactsGateway {
    func all(_ completionHandler: (Result<[Contact], ContactError>) -> Void) { }
}

final class ContactsArrayGateway: ContactsGateway {
    func all(_ completionHandler: (Result<[Contact], ContactError>) -> Void) {
        let contacts = [Contact(street: "Rua da Vala, 666", city: "São Paulo", state: "SP", country: "BR")]
        completionHandler(.success(contacts))
    }
}

protocol ContactsPresenter: AnyObject {
    var binder: ContactsListBindable? { get set }
    func finded(contacts: [Contact])
    func failed(with error: ContactError)
}

final class ContactsViewModelPresenter: ContactsPresenter {
    weak var binder: ContactsListBindable?

    func failed(with error: ContactError) { }
    func finded(contacts: [Contact]) {
        let viewModels = contacts.map {
            ContactViewModel(fullAddress: "\($0.street) - \($0.city), \($0.state)")
        }
        binder?.bind(viewModels: viewModels)
    }
}

// MARK: - User interface

import UIKit

protocol ContactsListBindable: AnyObject {
    func bind(viewModels: [ContactViewModel])
}

extension UITableViewCell {
    static var identifier: String { return .init(describing: UITableViewCell.self) }
}

final class ContactsListViewController: UITableViewController, ContactsListBindable {
    private let interactor: ValidContractsInteractable
    private var viewModels: [ContactViewModel] = []

    init(interactor: ValidContractsInteractable, presenter: ContactsPresenter) {
        self.interactor = interactor
        super.init(style: .plain)
        presenter.binder = self
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: UITableViewCell.identifier)
        tableView.allowsSelection = false
        interactor.all()
    }

    func bind(viewModels: [ContactViewModel]) {
        self.viewModels = viewModels
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModels.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UITableViewCell.identifier, for: indexPath)
        cell.textLabel?.text = viewModels[indexPath.row].fullAddress
        return cell
    }
}

// MARK: - Dependency Injection with Factories

final class ContactsListViewControllerFactory {
    private init() { }

    static func make() -> UIViewController {
        let presenter = ContactsPresenterFactory.make()
        let interactor = ValidContractsInteractorFactory.make(presenter: presenter)
        let viewController = ContactsListViewController(interactor: interactor, presenter: presenter)
        return viewController
    }
}

final class ValidContractsInteractorFactory {
    private init() { }

    static func make(presenter: ContactsPresenter) -> ValidContractsInteractable {
        return ValidContractsInteractor(gateway: ContactsGatewayFactory.make(), presenter: presenter)
    }
}

final class ContactsGatewayFactory {
    private init() { }

    static func make() -> ContactsGateway {
        return ContactsArrayGateway()
    }
}

final class ContactsPresenterFactory {
    private init() { }

    static func make() -> ContactsPresenter {
        return ContactsViewModelPresenter()
    }
}

// MARK: - Dependency Injection with Needle

import NeedleFoundation

final class RootComponent: BootstrapComponent {
    var contactsGateway: ContactsGateway {
        return ContactsArrayGateway()
    }

    var contactsListComponent: ContactsListComponent {
        return ContactsListComponent(parent: self)
    }

    var rootViewController: UIViewController {
        return contactsListComponent.viewController
    }
}

protocol ContactsListDependency: Dependency {
    var contactsGateway: ContactsGateway { get }
}

final class ContactsListComponent: Component<ContactsListDependency> {
    var interactor: ValidContractsInteractor {
        return ValidContractsInteractor(gateway: dependency.contactsGateway, presenter: presenter)
    }

    var viewController: UIViewController {
        return ContactsListViewController(interactor: interactor, presenter: presenter)
    }

    var presenter: ContactsPresenter {
        return shared { ContactsViewModelPresenter() }
    }
}
