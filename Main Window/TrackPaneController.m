//
//  TrackPaneController.m
//  Ascent
//
//  Created by Rob Boyer on 9/25/25.
//  Copyright © 2025 Montebello Software, LLC. All rights reserved.
//
//

#import "TrackPaneController.h"
#import "TrackListController.h"
#import "TrackCalendarController.h"

@implementation TrackPaneController

@synthesize document = _document;
@synthesize selection = _selection;
@synthesize controlsBar = _controlsBar;
@synthesize viewModeControl = _viewModeControl;
@synthesize searchField = _searchField;
@synthesize outlineOptionsMenu = _outlineOptionsMenu;
@synthesize contentContainer = _contentContainer;
@synthesize calendarMode = _calendarMode;


- (void)dealloc {
    [_outlineVC release];
    [_calendarVC release];
    [_selection release];
    [super dealloc];
}


- (void)awakeFromNib
{
    [super awakeFromNib];

    if (_controlsBar != nil) {
        _controlsBar.material = NSVisualEffectMaterialHeaderView;
        _controlsBar.blendingMode = NSVisualEffectBlendingModeWithinWindow;
        _controlsBar.state = NSVisualEffectStateFollowsWindowActiveState;
    }

    TrackListController *outline = [[TrackListController alloc] initWithNibName:@"TrackListController" bundle:nil];
    _outlineVC = outline;

    TrackCalendarController *calendar = [[TrackCalendarController alloc] initWithNibName:@"TrackCalendarController" bundle:nil];
    _calendarVC = calendar;

    [self injectDependencies];

    [self setCalendarMode:NO];

    if (_viewModeControl != nil) {
        [_viewModeControl setTarget:self];
        [_viewModeControl setAction:@selector(toggleViewMode:)];
    }
}

- (IBAction)toggleViewMode:(id)sender
{
    BOOL wantCalendar = NO;
    if ([sender respondsToSelector:@selector(selectedSegment)]) {
        wantCalendar = ([(NSSegmentedControl *)sender selectedSegment] == 1);
    }
    [self setCalendarMode:wantCalendar];
}

- (void)setCalendarMode:(BOOL)calendarMode
{
    if (!_document)
        return;
    
    _calendarMode = calendarMode;

    NSViewController *target = nil;
    if (_calendarMode) {
        target = _calendarVC;
        _searchField.enabled = NO;
        _outlineOptionsMenu.enabled = NO;
    } else {
        target = _outlineVC;
        _searchField.enabled = YES;
        _outlineOptionsMenu.enabled = YES;
    }

    if (_current == target) {
        return;
    }

    if (_current != nil) {
        [[_current view] removeFromSuperview];
        [_current removeFromParentViewController];
    }

    _current = target;

    if (_current == nil) {
        return;
    }

    [self addChildViewController:_current];

    NSView *v = _current.view;
    v.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentContainer addSubview:v];

    [NSLayoutConstraint activateConstraints:@[
        [v.leadingAnchor constraintEqualToAnchor:_contentContainer.leadingAnchor],
        [v.trailingAnchor constraintEqualToAnchor:_contentContainer.trailingAnchor],
        [v.topAnchor constraintEqualToAnchor:_contentContainer.topAnchor],
        [v.bottomAnchor constraintEqualToAnchor:_contentContainer.bottomAnchor]
    ]];
    
    if (!calendarMode) {
        [_outlineVC buildBrowser:YES];
    }
}

- (void)setDocument:(TrackBrowserDocument *)document
{
    _document = document;
    [self injectDependencies];
}

- (void)setSelection:(Selection *)selection
{
    if (selection == _selection) {
        return;
    }
    if (_selection != nil) {
        [_selection release];
    }
    _selection = [selection retain];
    [self injectDependencies];
}

- (void)injectDependencies
{
    NSViewController *vc = nil;

    vc = _outlineVC;
    if (vc != nil) {
        @try { [vc setValue:_document forKey:@"document"]; }
        @catch (__unused NSException *ex) {}
        @try { [vc setValue:_selection forKey:@"selection"]; }
        @catch (__unused NSException *ex) {}
        if ([vc respondsToSelector:@selector(injectDependencies)]) {
            [vc performSelector:@selector(injectDependencies)];
        }
    }

    vc = _calendarVC;
    if (vc != nil) {
        @try { [vc setValue:_document forKey:@"document"]; }
        @catch (__unused NSException *ex) {}
        @try { [vc setValue:_selection forKey:@"selection"]; }
        @catch (__unused NSException *ex) {}
        if ([vc respondsToSelector:@selector(injectDependencies)]) {
            [vc performSelector:@selector(injectDependencies)];
        }
    }
}


- (IBAction)setSearchOptions:(id)sender
{
    if (_current == _outlineVC)
    {
        [_outlineVC setSearchOptions:sender];
    }
}


- (IBAction)setSearchCriteria:(id)sender
{
    if (_current == _outlineVC)
    {
        [_outlineVC setSearchCriteria:sender];
    }
}

@end
