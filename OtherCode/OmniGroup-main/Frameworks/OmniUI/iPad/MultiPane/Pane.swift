// Copyright 2016-2021 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

import UIKit

/// Pane: type that wraps a view controller with the settings necessary for it to be managed by the MultiPaneController.
/// NOTE: Given the unknowns of how Omni would use MultiPane, many properties have been left as internal until there is a need for them to be public.
///       The PaneConfiguration and the PaneEnviroment could be properties and types to expose to clients since they provide all the configuration that gets applied to a Pane and its managed view controller by the MPC.
///       Properties and functions currently marked private probably don't make sense to change externally and should be left that way.
@objc(OUIMultiPane) open class Pane: NSObject {
    @objc public let viewController: UIViewController

    @objc public var preferredMinimumWidth: CGFloat {
        get {
            return configuration.preferredMinimumWidth
        }
        set {
            configuration.preferredMinimumWidth = newValue
        }
    }
    
    /// Does this pane style support pinning
    public var isPinnable: Bool {
        return configuration.canBePinned
    }
    
    public var dividerColor: UIColor? {
        get {
            guard let configuration = configuration as? Sidebar else { return nil }
            return configuration.divider?.color
        }
        set {
            guard let configuration = configuration as? Sidebar else { return }
            configuration.divider?.color = newValue ?? PaneDividerView.defaultColor
        }
    }

    public var editingDividerColor: UIColor? {
        get {
            guard let configuration = configuration as? Sidebar else { return nil }
            return configuration.divider?.editingColor
        }
        set {
            guard let configuration = configuration as? Sidebar else { return }
            configuration.divider?.editingColor = newValue ?? PaneDividerView.defaultEditingColor
        }
    }

    /// The width of the center pane to use when deciding what style of pinning can be used.
    /// If pinning a pane would cause this threshold to be exceeded, then the pinning system will push the other sidebar pane out of the way.
    /// Otherwise, it will try to pin in place without changing the other pane.
    /// (Note, better to use this than the preferredMinimumWidth of the center pane so that other layout can happen regardless of whether you are opting into pinning or not.)
    public var centerPanePinWidthThreshold: CGFloat = 320
    
    /// Signal that this pane wants to participate in Pinning.
    /// No-op if pane doesn't support pinning (.center panes don't support pinning)
    /// Note: This only lets the system know that this pane wants to be part of pinning.
    public var wantsToBePinnable: Bool {
        set (newValue) {
            guard configuration is Sidebar else {
                // Trying to pin the Center Pane isn't supported.
                assertionFailure("Pane type doen't participate in pinning, changing this value will have no effect")
                return
            }
            
            configuration.canBePinned = newValue
        }
        
        get {
            return isPinnable
        }
    }
    
    /// Is this Pane currently pinned.
    public var isPinned: Bool {
        return environment?.presentationMode == .embedded && configuration.isPinned
    }
    
    @objc public var isPresentedInOverlay: Bool {
        return environment?.presentationMode == .overlaid && isVisible
    }

    // describes the type of pane, where it lives, and how it behaves in the curent environment
    var configuration: PaneConfiguration
    
    // describes the presentation and size of the pane in the current MultiPaneDisplayMode
    var environment: PaneEnvironment? {
        didSet {
            if let oldEnv = oldValue {
                // clear out the decorations for the old environment
                self.apply(decorations: self.configuration.decorations(forEnvironment: oldEnv))
            }
            
            if let env = self.environment {
                self.update(withEnvironment: env)
            }
        }
    }
    
    // embedded width
    var width: CGFloat {
        return self.widthConstraint?.constant ?? 0.0
    }
    
    var preferredWidth: CGFloat = 0.0 {
        didSet {
            self.widthConstraint?.constant = preferredWidth
        }
    }
    
    var visibleWhenEmbedded = true
    
    init(withViewController viewController: UIViewController, configuration: PaneConfiguration) {
        self.viewController = viewController
        self.configuration = configuration
    }
    
    /// initialize a pane using the default Configuration for the location type
    convenience init(withViewController viewController: UIViewController, location: MultiPaneLocation) {
        let config = location.defaultConfiguration
        self.init(withViewController: viewController, configuration: config)
    }
    
    /// called prior to displaying the view controller
    func prepareForDisplay() {
        guard let environment = self.environment else {
            assertionFailure("expected to have an environment before display time")
            return
        }
        
        // apply any decorations to this pane for the current environment
        self.configuration.configure(withViewController: self.viewController)
        self.apply(decorations: self.configuration.decorations(forEnvironment: environment))
    }
    
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        guard viewController.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }

        if let environment = environment {
            apply(decorations: configuration.decorations(forEnvironment: environment))
        }
    }

    func apply(decorations: [PaneDecoration]) {
        for decoration in decorations {
            configuration.apply(decoration: decoration, toViewController: viewController)
        }
    }

    //MARK: Private

    private var needsInitialSetup: Bool = true

    private var widthConstraint: NSLayoutConstraint? {
        didSet {
            guard let widthConstraint = self.widthConstraint else { return }
            let priority: UILayoutPriority = self.configuration.widthPriority
            widthConstraint.priority = priority
            widthConstraint.isActive = true
        }
    }
    
    private var heightConstraint: NSLayoutConstraint? {
        didSet {
            guard let heightConstraint = self.heightConstraint else { return }
            heightConstraint.priority = self.configuration.heightPriority
            heightConstraint.isActive = true
        }
    }
    
    /// update the pane with the current environment. Pane's view controller may or may not be parented at this time.
    private func update(withEnvironment env: PaneEnvironment) {
        if self.needsInitialSetup { self.initialSetup() }
        
        // reset to identity in case it was changed during a presentation.
        self.viewController.view.transform = CGAffineTransform.identity
        
        // setup a base frame so that the view has something work work with.
        let size = self.configuration.size(withEnvironment: env)
        var frame = self.viewController.view.frame
        frame.size = size
        self.viewController.view.frame = frame
        self.preferredWidth = size.width
        
        // apply the width/height constraints for embedded views.
        // TODO: we should wrap our VCs in a view and set the contraints on that view instead.
        if env.presentationMode == .embedded {
            self.viewController.view.translatesAutoresizingMaskIntoConstraints = false
            self.widthConstraint?.isActive = true
            self.heightConstraint?.isActive = true
            self.widthConstraint?.constant = size.width
            self.heightConstraint?.constant = size.height
            
        } else {
            self.widthConstraint?.isActive = false
            self.heightConstraint?.isActive = false
            if viewControllerIsWrappedInWrapperController {
                self.viewController.view.translatesAutoresizingMaskIntoConstraints = false
                self.viewController.parent?.view.translatesAutoresizingMaskIntoConstraints = true
            } else {
                self.viewController.view.translatesAutoresizingMaskIntoConstraints = true
            }
        }
    }
    
    private var viewControllerIsWrappedInWrapperController: Bool {
        return viewController.parent is MultipanePresentationWrapperViewController
    }
    
    private func initialSetup() {
        guard self.needsInitialSetup == true else { return }
        self.needsInitialSetup = false
        
        let view = self.viewController.view
        view?.translatesAutoresizingMaskIntoConstraints = false
        view?.setContentCompressionResistancePriority(.required, for: .horizontal)
        self.widthConstraint = view?.widthAnchor.constraint(equalToConstant: 0.0)
        self.heightConstraint = view?.heightAnchor.constraint(equalToConstant: 0.0)
    }
}

// MARK: -

extension MultiPaneLocation {
    var defaultConfiguration: PaneConfiguration {
        switch self {
        case .left:
            return Left()
        case .right:
            return Right()
        default:
            return ContentPane()
        }
    }
}

//MARK: -
//MARK: Pane Environment
//MARK: -

// size-class dependent settings.
protocol PaneEnvironment {
    var presentationMode: MultiPanePresentationMode { get }
    var containerSize: CGSize { get }
}

//MARK: -

// Regular width environment
struct RegularEnvironment: PaneEnvironment {
    let presentationMode: MultiPanePresentationMode
    let containerSize: CGSize
    init(withPresentationMode mode: MultiPanePresentationMode, containerSize: CGSize) {
        self.presentationMode = mode // enforce that the mode should be .overlaid or .embedded?
        self.containerSize = containerSize
    }
}

//MARK: -

// compact width environment
struct CompactEnvironment: PaneEnvironment {
    let presentationMode: MultiPanePresentationMode
    var transitionStyle: MultiPaneCompactTransitionStyle = .modal
    let containerSize: CGSize
    init(withPresentationMode mode: MultiPanePresentationMode, containerSize: CGSize) {
        self.presentationMode = mode // enforce that the mode should be .embedded or .none?
        self.containerSize = containerSize
    }
}

//MARK: -

extension UIViewController {
    @objc var isVisible: Bool {
        guard self.isViewLoaded else { return false }
        guard let view = self.view else { return false }

        let hasWindow = (view.window != nil)
        var hasFullscreenPresentedViewController: Bool = false
        if let presented = presentedViewController, presented.modalPresentationStyle == .currentContext || presented.modalPresentationStyle == .fullScreen {
            hasFullscreenPresentedViewController = true
        }
        guard hasWindow || hasFullscreenPresentedViewController else { return false }
        
        if let superView = view.superview {
            let frame = view.frame
            let contains = superView.bounds.contains(frame)
            let intersects = superView.bounds.intersects(frame)
            return contains || intersects // may be at the start or middle of a rotation when this is called, so checking the intersection is also necessary to determine visibility
        }
        return false
    }
    
    @objc var isVisibleAndAncestorsAreVisible: Bool {
        if let parent = parent {
            guard parent.isVisibleAndAncestorsAreVisible else { return false }
        }
        return isVisible
    }
    
    @objc public var furthestAncestor: UIViewController {
        var ancestor = self
        while let parent = ancestor.parent {
            ancestor = parent
        }
        return ancestor
    }
    
    public func isOrHasAncestor(_ possibleAncestor: UIViewController) -> Bool {
        guard possibleAncestor != self else { return true }
        var ancestor = self
        while let parent = ancestor.parent {
            if possibleAncestor == parent {
                return true
            }
            ancestor = parent
        }
        return false
    }
}
