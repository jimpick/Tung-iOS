//
//  WelcomePopupView.m
//  Tung
//
//  Created by Jamie Perkins on 11/19/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//

#import "WelcomePopupView.h"
#import "KLCPopup.h"
#import "TungCommonObjects.h"

@implementation WelcomePopupView

-(id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [[NSBundle mainBundle] loadNibNamed:@"WelcomePopupView" owner:self options:nil];
        self.bounds = self.view.bounds;
        [self addSubview:self.view];
        
        [self setProperties];
    }
    return self;
}

-(id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [[NSBundle mainBundle] loadNibNamed:@"WelcomePopupView" owner:self options:nil];
        [self addSubview:self.view];
        
        [self setProperties];
    }
    return self;
}

- (void) setProperties {
    
    [self.view.layer setCornerRadius:18.0];
    _solidCircle.type = kMiscViewTypeSolidCircle;
    
    _scrollView.delegate = self;
    
    _header0.text = @"Welcome!";
    _body0.text = @"The big purple button on the bottom of your screen is the play/pause button.\n\nHere’s a tour of the other 4 buttons beside it.";
    [_button0 setTitle:@"Show me" forState:UIControlStateNormal];
    [_button0 addTarget:self action:@selector(nextPage) forControlEvents:UIControlEventTouchUpInside];
    
    _header1.text = @"The Feed";
    _iconView1.type = kIconTypeFeed;
    _body1.text = @"Where you’ll find clips, comments and recomendations from the people you follow.";
    [_button1 setTitle:@"Next" forState:UIControlStateNormal];
    [_button1 addTarget:self action:@selector(nextPage) forControlEvents:UIControlEventTouchUpInside];
    _reverseIconView1.type = kIconTypeFeed;
    _reverseIconView1.color = [UIColor whiteColor];
    
    _header2.text = @"Now Playing";
    _iconView2.type = kIconTypeNowPlaying;
    _body2.text = @"Always has what’s currently playing. You can record clips, comment, and recommend a podcast from here.";
    [_button2 setTitle:@"Next" forState:UIControlStateNormal];
    [_button2 addTarget:self action:@selector(nextPage) forControlEvents:UIControlEventTouchUpInside];
    _reverseIconView2.type = kIconTypeNowPlaying;
    _reverseIconView2.color = [UIColor whiteColor];
    
    _header3.text = @"Subscriptions";
    _iconView3.type = kIconTypeSubscribe;
    _body3.text = @"All of the podcasts you’ve subscribed to.";
    [_button3 setTitle:@"Next" forState:UIControlStateNormal];
    [_button3 addTarget:self action:@selector(nextPage) forControlEvents:UIControlEventTouchUpInside];
    _reverseIconView3.type = kIconTypeSubscribe;
    _reverseIconView3.color = [UIColor whiteColor];
    
    _header4.text = @"Your Profile";
    _iconView4.type = kIconTypeProfile;
    _body4.text = @"Has your notifications, and all of your activity that’s published in the feed.";
    [_button4 setTitle:@"Got it!" forState:UIControlStateNormal];
    [_button4 addTarget:self action:@selector(dismiss:) forControlEvents:UIControlEventTouchUpInside];
    _reverseIconView4.type = kIconTypeProfile;
    _reverseIconView4.color = [UIColor whiteColor];
    
    CGRect maskFrame = CGRectMake(0, 0, 230, 55);
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(88, 0, 55, 55)];
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = maskFrame;
    maskLayer.path = maskPath.CGPath;
    _iconScrollViewContainer.layer.mask = maskLayer;
     
}

- (void) nextPage {
    
    CGPoint currentPoint = _scrollView.contentOffset;
    CGSize size = _scrollView.frame.size;
    CGRect nextRect = {currentPoint, size};
    nextRect.origin.x += size.width;
    
    [_scrollView scrollRectToVisible:nextRect animated:YES];
}

- (void) dismiss:(id)sender {
    if ([sender isKindOfClass:[UIView class]]) {
        SettingsEntity *settings = [TungCommonObjects settings];
        settings.hasSeenWelcomePopup = [NSNumber numberWithBool:YES];
        [TungCommonObjects saveContextWithReason:@"has seen welcome tutorial"];
        [(UIView*)sender dismissPresentingPopup];
    }
}

- (void) setContentSize {
    
    CGSize contentSize = _scrollView.contentSize;
    //NSLog(@"scroll view content size: %@", NSStringFromCGSize(_scrollView.contentSize));
    contentSize.width = contentSize.width * 5;
    _scrollView.contentSize = contentSize;
    _scrollView.contentInset = UIEdgeInsetsZero;
    
    CGSize iconContentSize = _iconScrollView.contentSize;
    iconContentSize.width = iconContentSize.width * 5;
    _iconScrollView.contentSize = iconContentSize;
    _iconScrollView.contentInset = UIEdgeInsetsZero;
}

#pragma mark - scroll view delegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == _scrollView) {
        CGPoint offset = _scrollView.contentOffset;
        _iconScrollView.contentOffset = offset;
        // control alpha of solid circle
        if (scrollView.contentOffset.x <= 230.0) {
            float alpha = scrollView.contentOffset.x / 230.0;
            _solidCircle.alpha = alpha;
        }
    }
}


@end
