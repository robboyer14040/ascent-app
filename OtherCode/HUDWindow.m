//
//  HUDWindow.m
//  HUDWindow
//
//  Created by Matt Gemmell on 12/02/2006.
//  Copyright 2006 Magic Aubergine. All rights reserved.
//

#import "HUDWindow.h"

@implementation HUDWindow


- (id)initWithContentRect:(NSRect)contentRect 
                styleMask:(NSWindowStyleMask)styleMask
                  backing:(NSBackingStoreType)bufferingType 
                    defer:(BOOL)flag 
{
    if (self = [super initWithContentRect:contentRect 
                                styleMask:NSWindowStyleMaskBorderless
                                  backing:bufferingType 
                                    defer:flag]) {
        
        [self setFrameUsingName:@"HUDWindowFrame"];
        [self setBackgroundColor: [NSColor clearColor]];
        [self setAlphaValue:1.0];
        [self setOpaque:NO];
        [self setHasShadow:NO];
        [self setMovableByWindowBackground:YES];
        [self setDelegate:self];
        forceDisplay = NO;
        [self setBackgroundColor:[self sizedHUDBackground]];
        
        [self addCloseWidget];
        [self setFloatingPanel:YES];
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(windowDidResize:) 
                                                     name:NSWindowDidResizeNotification 
                                                   object:self];
        
        return self;
    }
    return nil;
}



- (void)awakeFromNib
{
   [self setFrameUsingName:@"HUDWindowFrame"];
   [self addCloseWidget];
}

- (void)fade:(NSTimer *)theTimer
{
   if ([self alphaValue] > 0.0) 
   {
      // If window is still partially opaque, reduce its opacity.
      [self setAlphaValue:[self alphaValue] - 0.2];
   } 
   else 
   {
      // Otherwise, if window is completely transparent, destroy the timer and close the window.
      [fadeTimer invalidate];

      fadeTimer = nil;
      
      [self close];
      
      // Make the window fully opaque again for next time.
      [self orderOut:self];
      [self setAlphaValue:1.0];
   }
}

static const float kHeightCutoff = 120.0;

-(void)fadeOut
{
   fadeTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(fade:) userInfo:nil repeats:YES];
   [[NSNotificationCenter defaultCenter] postNotificationName:@"HUDClosed" object:self];
}

- (void)addCloseWidget
{
   float sz = 13.0;
   float sp = 3.0;
   NSRect f = [self frame];
   
   if (f.size.height < kHeightCutoff)
   {
      sz = 9.0;
      sp = 2.0;
   }
   
    NSButton *closeButton = [[NSButton alloc] initWithFrame:NSMakeRect(sp, [self frame].size.height - (sz+sp), 
                                                                       sz, sz)];
    
    [[self contentView] addSubview:closeButton];
    [closeButton setBezelStyle:NSRoundedBezelStyle];
    [closeButton setButtonType:NSMomentaryChangeButton];
    [closeButton setBordered:NO];
    [closeButton setImage:[NSImage imageNamed:@"hud_titlebar-close"]];
    [closeButton setTitle:@""];
    [closeButton setImagePosition:NSImageBelow];
    [closeButton setTarget:self];
    [closeButton setFocusRingType:NSFocusRingTypeNone];
    //[closeButton setAction:@selector(orderOut:)];
    [closeButton setAction:@selector(fadeOut)];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResizeNotification object:self];    
}

- (void)windowDidResize:(NSNotification *)aNotification
{
   [self setBackgroundColor:[self sizedHUDBackground]];
   [self saveFrameUsingName:@"HUDWindowFrame"];
    if (forceDisplay) {
        [self display];
    }
}

- (void)windowDidMove:(NSNotification *)aNotification
{
   [self saveFrameUsingName:@"HUDWindowFrame"];
}


- (void)setFrame:(NSRect)frameRect display:(BOOL)displayFlag animate:(BOOL)animationFlag
{
    forceDisplay = YES;
    [super setFrame:frameRect display:displayFlag animate:animationFlag];
    forceDisplay = NO;
}

- (NSColor *)sizedHUDBackground
{
   NSRect f = [self frame];
   float titlebarHeight = 19.0;
   NSControlSize tsz = NSSmallControlSize;
   if (f.size.height < kHeightCutoff)
   {
      titlebarHeight = 13.0;
      tsz = NSMiniControlSize;
   }
   float alpha = 0.75;
    NSImage *bg = [[NSImage alloc] initWithSize:f.size];
    [bg lockFocus];
    
    // Make background path
    NSRect bgRect = NSMakeRect(0, 0, [bg size].width, [bg size].height - titlebarHeight);
    int minX = NSMinX(bgRect);
    int midX = NSMidX(bgRect);
    int maxX = NSMaxX(bgRect);
    int minY = NSMinY(bgRect);
    int midY = NSMidY(bgRect);
    int maxY = NSMaxY(bgRect);
    float radius = 6.0;
    NSBezierPath *bgPath = [NSBezierPath bezierPath];
    
    // Bottom edge and bottom-right curve
    [bgPath moveToPoint:NSMakePoint(midX, minY)];
    [bgPath appendBezierPathWithArcFromPoint:NSMakePoint(maxX, minY) 
                                     toPoint:NSMakePoint(maxX, midY) 
                                      radius:radius];
    
    [bgPath lineToPoint:NSMakePoint(maxX, maxY)];
    [bgPath lineToPoint:NSMakePoint(minX, maxY)];
    
    // Top edge and top-left curve
    [bgPath appendBezierPathWithArcFromPoint:NSMakePoint(minX, maxY) 
                                     toPoint:NSMakePoint(minX, midY) 
                                      radius:radius];
    
    // Left edge and bottom-left curve
    [bgPath appendBezierPathWithArcFromPoint:bgRect.origin 
                                     toPoint:NSMakePoint(midX, minY) 
                                      radius:radius];
    [bgPath closePath];
    
    // Composite background color into bg
    [[NSColor colorWithCalibratedWhite:0.1 alpha:alpha] set];
    [bgPath fill];
    
    // Make titlebar path
    NSRect titlebarRect = NSMakeRect(0, [bg size].height - titlebarHeight, [bg size].width, titlebarHeight);
    minX = NSMinX(titlebarRect);
    midX = NSMidX(titlebarRect);
    maxX = NSMaxX(titlebarRect);
    minY = NSMinY(titlebarRect);
    midY = NSMidY(titlebarRect);
    maxY = NSMaxY(titlebarRect);
    NSBezierPath *titlePath = [NSBezierPath bezierPath];
    
    // Bottom edge and bottom-right curve
    [titlePath moveToPoint:NSMakePoint(minX, minY)];
    [titlePath lineToPoint:NSMakePoint(maxX, minY)];
    
    // Right edge and top-right curve
    [titlePath appendBezierPathWithArcFromPoint:NSMakePoint(maxX, maxY) 
                                     toPoint:NSMakePoint(midX, maxY) 
                                      radius:radius];
    
    // Top edge and top-left curve
    [titlePath appendBezierPathWithArcFromPoint:NSMakePoint(minX, maxY) 
                                     toPoint:NSMakePoint(minX, minY) 
                                      radius:radius];
    
    [titlePath closePath];
    
    // Titlebar
    NSColor *titlebarColor = [NSColor colorWithCalibratedWhite:0.25 alpha:alpha];
    [titlebarColor set];
    [titlePath fill];
    
    // Title
    NSFont *titleFont = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:tsz]];
    NSMutableParagraphStyle *paraStyle = [[NSMutableParagraphStyle alloc] init];
    [paraStyle setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
    [paraStyle setAlignment:NSCenterTextAlignment];
    [paraStyle setLineBreakMode:NSLineBreakByTruncatingTail];
    NSMutableDictionary *titleAttrs = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        titleFont, NSFontAttributeName,
        [NSColor whiteColor], NSForegroundColorAttributeName,
        [paraStyle copy], NSParagraphStyleAttributeName,
        nil];
    
    NSSize titleSize = [[self title] sizeWithAttributes:titleAttrs];
    // We vertically centre the title in the titlbar area, and we also horizontally 
    // inset the title by 19px, to allow for the 3px space from window's edge to close-widget, 
    // plus 13px for the close widget itself, plus another 3px space on the other side of 
    // the widget.
    NSRect titleRect = NSInsetRect(titlebarRect, titlebarHeight, (titlebarRect.size.height - titleSize.height) / 2.0);
    [[self title] drawInRect:titleRect withAttributes:titleAttrs];
    [bg unlockFocus];
    
    return [NSColor colorWithPatternImage:bg];
}

- (void)setTitle:(NSString *)value {
    [super setTitle:value];
    [self windowDidResize:nil];
}


- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)canBecomeMainWindow { return NO; } // also prevent becoming main

// If anything calls these, do not try to become key; just show the window.
- (void)makeKeyAndOrderFront:(id)sender
{
    [self orderFront:sender];
}
- (void)makeKeyWindow
{
    /* no-op on purpose */
}




@end
