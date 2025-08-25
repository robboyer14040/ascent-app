#import "PrefUtils.h"
#import <OmniAppKit/OAPreferenceController.h>
#import <AppKit/AppKit.h>       // umbrella, includes NSNibLoading

@implementation GeneralPrefsClient

- (instancetype)initWithPreferenceClientRecord:(OAPreferenceClientRecord *)rec
                                    controller:(OAPreferenceController *)controller
{
    self = [super initWithPreferenceClientRecord:rec controller:controller];
    if (!self) return nil;

    // Load your pane UI (File's Owner = GeneralPrefsClient).
    [[NSBundle mainBundle] loadNibNamed:@"PrefsGeneral" owner:self topLevelObjects:nil];

    // If you’re using Auto Layout and want OAPreferenceController to use fittingSize:
    // (Only do this if the nib is Auto Layout–based.)
    // Override wantsAutosizing in a category or here if your headers allow.
    return self;
}

// Called when values change or pane becomes current; implement as needed.
- (void)updateUI { /* read defaults / refresh controls if not using bindings */ }
- (IBAction)setValueForSender:(id)sender { /* write values if not using bindings */ }
- (void)willBecomeCurrentPreferenceClient { }
- (void)didBecomeCurrentPreferenceClient { }
- (void)resignCurrentPreferenceClient { }

// If your nib uses Auto Layout and you want the controller to size to fitting width:
- (BOOL)wantsAutosizing { return YES; }

@end
