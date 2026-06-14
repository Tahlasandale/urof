//
//  ShareViewController.swift
//  ShareExtension
//
//  Créé pour le projet Flutter UROF.
//  Gère l'interception de texte partagé et communique avec l'application principale via App Group.
//

import UIKit
import MobileCoreServices

class ShareViewController: UIViewController {
    
    // MARK: - Éléments UI
    
    // Titre de l'extension
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Partager avec UROF"
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Zone de texte pour visualiser le contenu récupéré
    private let textView: UITextView = {
        let tv = UITextView()
        tv.font = UIFont.systemFont(ofSize: 16)
        tv.textColor = .label
        tv.backgroundColor = .secondarySystemBackground
        tv.layer.cornerRadius = 12
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        tv.isEditable = false
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    
    // Indicateur de chargement pendant l'extraction du texte
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // Bouton pour annuler
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Annuler", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.systemRed, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // Bouton pour valider et envoyer
    private let shareButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Enregistrer", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        button.setTitleColor(.systemBlue, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isEnabled = false // Désactivé par défaut jusqu'à ce que du texte soit chargé
        return button
    }()
    
    // Variable pour stocker le texte extrait
    private var sharedText: String?
    
    // MARK: - Cycle de vie
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSharedText()
    }
    
    // MARK: - Configuration UI
    
    private func setupUI() {
        // Appliquer un effet de flou en arrière-plan (effet verre dépoli premium)
        view.backgroundColor = .clear
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurVisualEffectView = UIVisualEffectView(effect: blurEffect)
        blurVisualEffectView.frame = view.bounds
        blurVisualEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurVisualEffectView)
        
        // Conteneur principal de type "carte" au centre de l'écran
        let containerView = UIView()
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 20
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.15
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 10
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // Ajout des sous-vues
        containerView.addSubview(titleLabel)
        containerView.addSubview(cancelButton)
        containerView.addSubview(shareButton)
        containerView.addSubview(textView)
        containerView.addSubview(activityIndicator)
        
        // Configuration des événements boutons
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(handleShare), for: .touchUpInside)
        
        // Définition des contraintes Auto Layout
        NSLayoutConstraint.activate([
            // Contraintes de la carte conteneur (centrée et prenant 50% de la hauteur)
            containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5),
            
            // Bouton Annuler (haut gauche)
            cancelButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            cancelButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            // Bouton Enregistrer (haut droit)
            shareButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            shareButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Titre (centré entre les boutons)
            titleLabel.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: cancelButton.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: shareButton.leadingAnchor, constant: -8),
            
            // Zone de texte pour afficher le contenu extrait
            textView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            textView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            // Spinner de chargement
            activityIndicator.centerXAnchor.constraint(equalTo: textView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: textView.centerYAnchor)
        ])
    }
    
    // MARK: - Extraction des données
    
    private func loadSharedText() {
        activityIndicator.startAnimating()
        textView.text = "Chargement du texte récupéré..."
        
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            showErrorAndExit()
            return
        }
        
        var textFound = false
        let group = DispatchGroup()
        
        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            
            for provider in attachments {
                // Recherche de contenu de type texte brut ("public.text")
                if provider.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil) { [weak self] (data, error) in
                        defer { group.leave() }
                        
                        if let text = data as? String {
                            self?.sharedText = text
                            textFound = true
                        }
                    }
                }
            }
        }
        
        // Une fois toutes les opérations asynchrones terminées
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.activityIndicator.stopAnimating()
            
            if textFound, let text = self.sharedText {
                self.textView.text = text
                self.shareButton.isEnabled = true
            } else {
                self.textView.text = "Aucun texte exploitable n'a été détecté."
                self.shareButton.isEnabled = false
            }
        }
    }
    
    private func showErrorAndExit() {
        activityIndicator.stopAnimating()
        textView.text = "Une erreur est survenue lors de la récupération."
        shareButton.isEnabled = false
    }
    
    // MARK: - Actions
    
    @objc private func handleCancel() {
        // Annule la requête de partage et ferme l'extension
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    @objc private func handleShare() {
        guard let text = sharedText, !text.isEmpty else {
            handleCancel()
            return
        }
        
        // 1. Sauvegarde dans les UserDefaults partagés de l'App Group
        if let sharedDefaults = UserDefaults(suiteName: "group.urof.share") {
            sharedDefaults.set(text, forKey: "sharedText")
            sharedDefaults.synchronize()
        }
        
        // 2. Tente de rediriger l'utilisateur vers l'application principale pour traiter le texte
        openMainApp()
    }
    
    private func openMainApp() {
        guard let url = URL(string: "urof://share") else {
            // Si l'URL est invalide, on quitte simplement l'extension
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        
        // Tente d'ouvrir via la méthode officielle du contexte d'extension
        self.extensionContext?.open(url, completionHandler: { [weak self] success in
            if !success {
                // Fallback : utilisation du responder chain pour invoquer openURL sur UIApplication
                let selector = Selector(("openURL:"))
                var responder: UIResponder? = self
                while let r = responder {
                    if r.responds(to: selector) {
                        r.perform(selector, with: url)
                        break
                    }
                    responder = r.next
                }
            }
            
            // Clôture définitive de l'extension de partage
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        })
    }
}
