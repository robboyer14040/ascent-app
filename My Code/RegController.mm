//
//  RegController.mm
//  Ascent
//
//  Created by Rob Boyer on 1/27/07.
//  Copyright 2007 Montebello Software. All rights reserved.
//

#import "RegController.h"
#import "Defs.h"

//#include "ZonicKRM.h"
//#include "KagiInterface.h"
//#include "KagiGenericACG.h"

@implementation RegController

#define CS @"SUPPLIERID:mbsoftware%E:4%N:4%H:1%COMBO:ee%SDLGTH:21%CONSTLGTH:2%CONSTVAL:S2%SEQL:1%ALTTEXT:Contact postmaster@montebellosoftware.com to obtain your registration code%SCRMBL:U9,,U5,,C1,,U8,,U13,,U7,,U16,,D3,,U11,,D2,,D0,,U1,,U15,,U19,,U20,,U2,,U6,,U18,,S0,,U17,,U0,,U4,,U14,,D1,,C0,,U10,,U12,,U3,,%ASCDIG:2%MATH:4A,,3S,,1M,,1M,,R,,R,,R,,R,,1M,,1M,,1M,,33S,,33S,,33S,,1M,,1M,,R,,0A,,0A,,0A,,1M,,1M,,1M,,1M,,R,,R,,R,,1M,,%BASE:30%BASEMAP:KEM6DWH54N289X7U31LJYRTCGQP0FA%REGFRMT:PROD-^#####-#####-#####-#####-#####-#####-#####-###[-#]"


- (id) init
{
   self = [super initWithWindowNibName:@"Reg"];
   return self;
}

+ (BOOL) c:(NSString*)nm em:(NSString*)em cd:(NSString*)tt
{
#if 0
    static KagiGenericACG* sACG = [KagiGenericACG acgWithConfigurationString:CS];
   [sACG retain];
   if ((em != nil) && (tt != nil))
   {
      return [sACG regCode:tt matchesName:@"" email:em hotSync:@""];
   }
   return NO;
#else
	NSLog(@"FIXME - NO LICENSE CHECK!");
    return YES;
#endif
}






+(BOOL) gi:(NSMutableString*)nm a2:(NSMutableString*)em a3:(NSMutableString*)tt
{
   BOOL ok = NO;
   NSDictionary* rdict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:RegistrationInfoDictionaryKey];
   if (rdict != nil)
   {
      //NSMutableString* d;
      NSMutableString* s = nil;
     
#if 0
       s = [rdict valueForKey:RegDummyKey1];
      if (s == nil) return NO;
      d = [NSMutableString stringWithString:s];
      sts = EncryptKRMString((CFMutableStringRef)d);
      
      s = [rdict valueForKey:RegDummyKey4];
      if (s == nil) return NO;
      d = [NSMutableString stringWithString:s];
      sts = EncryptKRMString((CFMutableStringRef)d);

      s = [rdict valueForKey:RegDummyKey2];
      if (s == nil) return NO;
      d = [NSMutableString stringWithString:s];
      sts = EncryptKRMString((CFMutableStringRef)d);
#endif
       
      s = [rdict valueForKey:RegCodeKey];
      if (s == nil) return NO;
      [tt setString:s];
      //sts = EncryptKRMString((CFMutableStringRef)tt);
      
#if 0
       s = [rdict valueForKey:RegDummyKey5];
      if (s == nil) return NO;
      d = [NSMutableString stringWithString:s];
      sts = EncryptKRMString((CFMutableStringRef)d);
      
      s = [rdict valueForKey:RegDummyKey3];
      if (s == nil) return NO;
      d = [NSMutableString stringWithString:s];
      sts = EncryptKRMString((CFMutableStringRef)d);
#endif
       
      s = [rdict valueForKey:RegNameKey];
      if (s == nil) return NO;
      [nm setString:s];
      // = EncryptKRMString((CFMutableStringRef)nm);
      
#if 0
     s = [rdict valueForKey:RegDummyKey6];
      if (s == nil) return NO;
      d = [NSMutableString stringWithString:s];
      sts = EncryptKRMString((CFMutableStringRef)d);
#endif
       
      s = [rdict valueForKey:RegEmailKey];
      if (s == nil) return NO;
      [em setString:s];
      //sts = EncryptKRMString((CFMutableStringRef)em);
      ok = YES;
   }
   return ok;
}   

-(void) awakeFromNib
{
   BOOL ok = NO;
   NSMutableString* nm = [NSMutableString stringWithString:@""];
   NSMutableString* em = [NSMutableString stringWithString:@""];
   NSMutableString* tt = [NSMutableString stringWithString:@""];
   
   ok = [RegController gi:nm a2:em a3:tt];
   if (ok)
   {
      [userNameField setStringValue:nm];
      [emailAddressField setStringValue:em];
      [codeField setStringValue:tt];
      ok = [RegController c:nm em:em cd:tt];
   }      
   [doneEnteringInfoButton setEnabled:ok];
}


+ (BOOL) CHECK_REGISTRATION
{
   BOOL ok = NO;
   NSMutableString* nm = [NSMutableString stringWithString:@""];
   NSMutableString* em = [NSMutableString stringWithString:@""];   
   NSMutableString* rc = [NSMutableString stringWithString:@""];
   ok = [RegController gi:nm a2:em a3:rc];
   if (ok) ok = [RegController c:nm em:em cd:rc];
   return ok;
}


- (void) storeRegInfo:(NSString*)tt name:(NSString*)nm email:(NSString*)em
{
   NSMutableDictionary* rdict = [NSMutableDictionary dictionaryWithCapacity:10];

   NSMutableString* s;
   //ZKRMModuleStatus sts;
   
#if 0
    s = [NSMutableString stringWithString:@"HIH7HD-QQGF5-IIJMN-LJKHF-992LT-XPCH4-K8XDC"];
   sts = EncryptKRMString((CFMutableStringRef)s);
   [rdict setObject:s forKey:RegDummyKey1];
   
   s = [NSMutableString stringWithString:@"PROD-G45KKK-OIGHO-7YU5T-PPYTR-992LT-LK77J-K8XDC-ZXT"];
   sts = EncryptKRMString((CFMutableStringRef)s);
   [rdict setObject:s forKey:RegDummyKey2];
#endif
    
   // CODE
   s = [NSMutableString stringWithString:tt];
   ///sts = EncryptKRMString((CFMutableStringRef)s);
   [rdict setObject:s forKey:RegCodeKey];

#if 0
    s = [NSMutableString stringWithString:@"ASNT-HUU7HD-POIUB-8UUYT-PPLOL-992LT-VB6GT-K8XDC-TYY"];
   sts = EncryptKRMString((CFMutableStringRef)s);
   [rdict setObject:s forKey:RegDummyKey3];
   
   s = [NSMutableString stringWithString:@"9KLJGG-PUU76-ZAQ23-OK887-KL077-OOUKM-K8XDC"];
   sts = EncryptKRMString((CFMutableStringRef)s);
   [rdict setObject:s forKey:RegDummyKey4];
#endif
    
   // NAME
   s = [NSMutableString stringWithString:nm];
   ///sts = EncryptKRMString((CFMutableStringRef)s);
   [rdict setObject:s forKey:RegNameKey];
   
#if 0
    s = [NSMutableString stringWithString:@"ASNT-TOV6BH-09OkJ-4G5JK-K098K-09L07-XPCH4-K8XDC-IUY"];
   sts = EncryptKRMString((CFMutableStringRef)s);
   [rdict setObject:s forKey:RegDummyKey5];
#endif
    
   // EMAIL
   s = [NSMutableString stringWithString:em];
   ///sts = EncryptKRMString((CFMutableStringRef)s);
   [rdict setObject:s forKey:RegEmailKey];
   
#if 0
   s = [NSMutableString stringWithString:@"PROD-G45KKK-OIGHO-7YU5T-PPYTR-992LT-LK77J-K8XDC-ZXT"];
   sts = EncryptKRMString((CFMutableStringRef)s);
   [rdict setObject:s forKey:RegDummyKey6];
#endif
   
   [[NSUserDefaults standardUserDefaults] setObject:rdict forKey:RegistrationInfoDictionaryKey];
}


#define KSM_PRODUCT_ID @"225162284050"


- (IBAction) buyIt:(id)sender
{
   [self close];
   [NSApp stopModal];

#if 0
    ZKRMParameters		theParameters;
	ZKRMResult			*theResult = 0;
	ZKRMModuleStatus	theStatus;
   
	// Prepare the KRM parameters
	//
	// This example uses relative pricing, where prices are tied to a base currency.
	GetPriceRelative(&theParameters);
	
   unsigned int foob = theParameters.moduleOptions;
	foob |= kZKRMOptionModalPrintDialogs;
   theParameters.moduleOptions = (ZKRMOptions)foob;
   
	// Invoke the KRM
	theStatus = [[ZonicKRMController sharedController] runModalKRMWithParameters:&theParameters toResult:&theResult];
   if (kZKRMModuleNoErr == theStatus)
   {
      if (theResult->moduleStatus == kZKRMModuleNoErr)
      {
         if (theResult->orderStatus == kZKRMOrderSuccess)
         {
            NSString* tt = [NSString stringWithString:(NSString*)(theResult->acgRegCode)];
            NSString* nm = [NSString stringWithString:(NSString*)(theResult->acgUserName)];
            NSString* em = [NSString stringWithString:(NSString*)(theResult->acgUserEmail)];
            [self storeRegInfo:tt name:nm email:em];
         }
      }
   }
               
	// Clean up
	if (theResult != 0) DisposeKRMResult(&theResult);
#else
	//[self displayMessage:@"you chose launch WebView"];
	///KSAObject* ksaObject = [KSAObject sharedInstance];
	
	///NSDictionary *parameters = [NSMutableDictionary dictionary];
	// REQUIRED
	///[parameters setValue:@"6FEFB_LIVE" forKey:KeyStoreId];
	
	// AT LEAST ONE OF THE FOLLOWING TWO IS REQUIRED
	///[parameters setValue:KSM_PRODUCT_ID forKey:KeyProductId];
	//[parameters setValue:@"workflow" forKey:KeyPage];
    
	// OPTIONAL
	// go straight to checkout page.
	///[parameters setValue:[NSNumber numberWithBool:YES] forKey:KeyGoToCheckout];
    
//	[parameters setValue:@"sergiu" forKey:KeyKagiAffiliate];
//	[parameters setValue:@"validcouponcode" forKey:KeyCouponCode];
//	[parameters setValue:@"en" forKey:KeyLanguage];
//	[parameters setValue:@"USD" forKey:KeyCurrency];
//	[parameters setValue:@"joe.buyer@domain.com" forKey:KeyCustomerEmail];
//	[parameters setValue:@"Joe Buyer" forKey:KeyCustomerBillingName];
//	[parameters setValue:@"My Company" forKey:KeyCustomerBillingCompany];
//	[parameters setValue:@"123 Any Street" forKey:KeyCustomerBillingStreet];
//	[parameters setValue:@"Apt. 456" forKey:KeyCustomerBillingStreet2];
//	[parameters setValue:@"San Francisco" forKey:KeyCustomerBillingCity];
//	[parameters setValue:@"CA" forKey:KeyCustomerBillingState];
//	[parameters setValue:@"94123" forKey:KeyCustomerBillingZip];
//	[parameters setValue:@"United States" forKey:KeyCustomerBillingCountry];
//	[parameters setValue:@"555-123-4567" forKey:KeyCustomerBillingPhone];
	
	
	//[ksaObject runModelessKSAWithParameters:parameters andCallBackObject:self];
    //////[ksaObject runModalKSAWithParameters:parameters andCallBackObject:self];
    
#endif
}


- (IBAction) notYet:(id)sender
{
   [self close];
   [NSApp stopModal];
}


- (IBAction) enterCode:(id)sender
{
   NSWindow* kw = [sender window];
   [enterCodePanel center];
   [enterCodePanel makeKeyAndOrderFront:sender];
   [doneEnteringInfoButton setEnabled:YES];
   [NSApp runModalForWindow:enterCodePanel];
   [enterCodePanel orderOut:sender];
   [kw makeKeyAndOrderFront:sender];
}


- (IBAction) doneEnteringInfo:(id)sender
{
   NSString* tt = [codeField stringValue];
   NSString* em = [emailAddressField stringValue];
   NSString* nm = [userNameField stringValue];
   BOOL ok = NO;
   BOOL exitLoop = NO;
   if ((em != nil) && (tt != nil))
   {
      ok = [RegController c:nm em:em cd:tt];
      if (ok)
      {
         [self storeRegInfo:tt name:nm email:em];
         exitLoop = YES;
      }
   }
   if (!ok)
   {
      NSAlert *alert = [[NSAlert alloc] init];
      [alert addButtonWithTitle:@"Retry"];
      [alert addButtonWithTitle:@"Cancel"];
      [alert setMessageText:@"Registration code not valid"];
      [alert setInformativeText:@"Please try re-entering the user name, email address and registration code exactly as it appears in the registration email."];
      [alert setAlertStyle:NSWarningAlertStyle];
      if ([alert runModal] != NSAlertFirstButtonReturn) 
      {
         exitLoop = YES;
      }
   }
   if (exitLoop)
   {
      [enterCodePanel close];
      [NSApp stopModal];
      if (ok)
      {
         [notYetButton setTitle:@"Done"];
         [notYetButton setKeyEquivalent:@"\r"];
         [purchaseButton setEnabled:NO];
         [enterCodeButton setEnabled:NO];
         [blurbText1 setStringValue:@"Thanks for purchasing Ascent!  Your support is appreciated."];
         [blurbText1 setNeedsDisplay:YES];
         [blurbText2 setStringValue:@""];
         [blurbText2 setNeedsDisplay:YES];
         [[blurbText2 window] setTitle:@"Thanks"];
         [[blurbText2 window] setViewsNeedDisplay:YES];
      }
   }
}


- (IBAction) cancelEnteringInfo:(id)sender
{
   [enterCodePanel close];
   [NSApp stopModal];
}


- (void)controlTextDidChange:(NSNotification *)aNotification
{
   BOOL matches = false;
   NSString* code = [codeField stringValue];
   NSString* emailAddress = [emailAddressField stringValue];
   NSString* nm = [userNameField stringValue];
   if ((code != nil) && (emailAddress != nil) && (nm != nil))
   {
      matches = [RegController c:nm em:emailAddress cd:code] == YES;
   }
   if (matches)
   {
      [doneEnteringInfoButton setKeyEquivalent:@"\r"];
   }
   else
   {
      [doneEnteringInfoButton setKeyEquivalent:@""];
   }
   //[doneEnteringInfoButton setEnabled:matches];
}


- (void)windowWillClose:(NSNotification *)aNotification
{
   [NSApp stopModal];
}


//------------------------------------------------------------------------------
//---- KSAResult protocol ------------------------------------------------------

-(void)setKSAResultAsDictionary:(NSDictionary *)result
{
#if 0
	NSLog(@" !!!! ASCENT: got kagiTransactionID: %@",[result valueForKey:KeyKagiTransactionId]);
	NSLog(@" !!!! ASCENT: got acgUserEmail: %@",[result valueForKey:KeyAcgUserEmail]);
	NSLog(@" !!!! ASCENT: LICENSES");
	
	NSArray *myLicenses = [result objectForKey:KeyLicenses];
	if (myLicenses != nil) {
		NSEnumerator *enumerator = [myLicenses objectEnumerator];
		NSDictionary *license;
		while (license = [enumerator nextObject]) {
			if (license != nil) {
				NSLog(@" !!!! ASCENT: got productID: %@",[license valueForKey:KeyProductId]);
				NSLog(@" !!!! ASCENT: got userName: %@",[license valueForKey:KeyAcgUserName]);
				NSLog(@" !!!! ASCENT: got regcode: %@",[license valueForKey:KeyAcgRegCode]);
			}
			NSLog(@" ------------------ SEPARATOR -----------------");
		}
	}

	[[self workFlowProController] set_kagiTransactionID:[result valueForKey:KeyKagiTransactionId]];
	[[self workFlowProController] set_acgUserEmail:[result valueForKey:KeyAcgUserEmail]];
	[[self workFlowProController] set_licenses:[result valueForKey:KeyLicenses]];
    
	[[self workFlowProController] updateLicense];
	
	NSMutableString* message = [NSMutableString stringWithFormat: @"WorkFlowPro was successfully registered!"];
	[self displayMessage:message];
#endif

}


-(void)setKSAError:(NSDictionary *)error
{
#if 0
	NSLog(@" !!!! got errorCode: %@",[error valueForKey:KeyErrorCode]);
	NSLog(@" !!!! got errorMessage: %@",[error valueForKey:KeyErrorMessage]);
	
	NSMutableString* message = [NSMutableString stringWithFormat: @"Got errorCode=%@ and errorMessage=%@",
								[error valueForKey:KeyErrorCode],
								[error valueForKey:KeyErrorMessage]];
	[self displayMessage:message];
#endif

}


-(void)setKSADeclined:(NSDictionary *)reason
{
#if 0
	NSLog(@" !!!! got reasonCode: %@",[reason valueForKey:KeyReasonCode]);
	NSLog(@" !!!! got reasonMessage: %@",[reason valueForKey:KeyReasonMessage]);
	
	NSMutableString* message = [NSMutableString stringWithFormat: @"Got reasonCode=%@ and reasonMessage=%@",
								[reason valueForKey:KeyReasonCode],
								[reason valueForKey:KeyReasonMessage]];
	[self displayMessage:message];
#endif

}



@end
