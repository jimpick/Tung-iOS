//
//  HeaderView.m
//  Tung
//
//  Created by Jamie Perkins on 5/3/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "HeaderView.h"
#import "EpisodeViewController.h"
#import "TungCommonObjects.h"

@implementation HeaderView

-(id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [[NSBundle mainBundle] loadNibNamed:@"HeaderView" owner:self options:nil];
        self.bounds = self.view.bounds;
        [self addSubview:self.view];
        
    }
    return self;
}

-(id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [[NSBundle mainBundle] loadNibNamed:@"HeaderView" owner:self options:nil];
        [self addSubview:self.view];
    }
    return self;
}

-(void) sizeAndSetTitleForText:(NSString *)titleText {
    //NSLog(@"size and set title for text length: %lu", (unsigned long)titleText.length);
    if (titleText.length > 60) {
        self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightLight];
    }
    else if (titleText.length > 30) {
        self.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightLight];
    }
    else if (titleText.length > 17) {
        self.titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightLight];
    }
    self.titleLabel.text = titleText;
}

// for quicker display of episode view header,
// stop gap while waiting for episode info to establish episode entity
-(void) setUpHeaderViewForEpisodeMiniDict:(NSDictionary *)miniDict {
    
    self.hidden = NO;
    self.clipsToBounds = YES;
    
    // title
    NSString *title = [miniDict objectForKey:@"title"];
    [self sizeAndSetTitleForText:title];
    self.subTitleLabel.text = @"";
    self.descriptionLabel.text = @"";
    
    // art image
    NSString *artUrlString = [miniDict objectForKey:@"artworkUrlSSL_sm"];
    NSData *artImageData = [TungCommonObjects retrieveDefaultSizePodcastArtDataWithUrlString:artUrlString];
    UIImage *artImage = [[UIImage alloc] initWithData:artImageData];
    self.albumArt.image = artImage;
    
    UIColor *keyColor = [TungCommonObjects colorFromHexString:[miniDict objectForKey:@"keyColor1Hex"]];
    UIColor *lighterKeyColor = [TungCommonObjects lightenKeyColor:keyColor];
    self.view.backgroundColor = lighterKeyColor;
    
    // hide buttons until we get entity
    self.largeButton.hidden = YES;
    self.subscribeButton.hidden = YES;
    
    
    [self adjustHeaderViewHeightForContent];
    
}

-(void) setUpHeaderViewWithBasicInfoForPodcast:(PodcastEntity *)podcastEntity {
    
    self.hidden = NO;
    self.clipsToBounds = YES;
    // text
    [self sizeAndSetTitleForText:podcastEntity.collectionName];
    self.subTitleLabel.text = [podcastEntity.artistName stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    self.descriptionLabel.text = @"Loading...";
    
    // art
    NSData *artImageData = [TungCommonObjects retrievePodcastArtDataForEntity:podcastEntity defaultSize:YES];
    UIImage *artImage = [[UIImage alloc] initWithData:artImageData];
    self.albumArt.image = artImage;
    
    // hide buttons for now
    self.largeButton.hidden = YES;
    self.subscribeButton.hidden = YES;
    
    // colors
    UIColor *keyColor1 = (UIColor *)podcastEntity.keyColor1;
    UIColor *lighterKeyColor = [TungCommonObjects lightenKeyColor:keyColor1];
    self.view.backgroundColor = lighterKeyColor;
    
    
    [self adjustHeaderViewHeightForContent];
    
}

static NSDateFormatter *airDateFormatter = nil;

- (void) setUpHeaderViewForEpisode:(EpisodeEntity *)episodeEntity orPodcast:(PodcastEntity *)podcastEntity {

    self.hidden = NO;
    self.clipsToBounds = YES;
    
    NSString *title, *subTitle, *desc;
    BOOL isSubscribed;
    NSData *artImageData;
    UIColor *keyColor1, *keyColor2;
    
    if ([TungCommonObjects screenSize].width < 375) {
        _descriptionLabel.numberOfLines = 2;
    }
    
    if (podcastEntity) {
        title = podcastEntity.collectionName;
        NSString *artist = [podcastEntity.artistName stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        subTitle = artist;
        if (podcastEntity.desc) {
        	desc = podcastEntity.desc;
        } else {
            desc = @"Loading...";
        }
        
        artImageData = [TungCommonObjects retrievePodcastArtDataForEntity:podcastEntity defaultSize:YES];
        
        isSubscribed = podcastEntity.isSubscribed.boolValue;
        keyColor1 = (UIColor *)podcastEntity.keyColor1;
        keyColor2 = (UIColor *)podcastEntity.keyColor2;
        
    }
    else {
        title = episodeEntity.title;
        if (!airDateFormatter) {
            airDateFormatter = [[NSDateFormatter alloc] init];
            [airDateFormatter setDateFormat:@"MMMM d, yyyy"];
        }
        subTitle = [self getSubtitleLabelTextForEntity:episodeEntity];
        desc = @"";
        
        artImageData = [TungCommonObjects retrievePodcastArtDataForEntity:episodeEntity.podcast defaultSize:YES];
        
        if (episodeEntity.episodeImageUrl) {
            //NSLog(@"episode image available! %@", episodeEntity.episodeImageUrl);
            // different than podcast art?
            if (episodeEntity.podcast.artworkUrl && ![episodeEntity.podcast.artworkUrl isEqualToString:episodeEntity.episodeImageUrl]) {
                
            }
        }
        
        isSubscribed = episodeEntity.podcast.isSubscribed.boolValue;
        
        keyColor1 = (UIColor *)episodeEntity.podcast.keyColor1;
        keyColor2 = (UIColor *)episodeEntity.podcast.keyColor2;
        
    }
    //NSLog(@"set up header view for %@", title);
    
    // art image
    UIImage *artImage = [[UIImage alloc] initWithData:artImageData];
    self.albumArt.image = artImage;
    
    NSString *keyColor1Hex = [TungCommonObjects UIColorToHexString:keyColor1];
    NSString *keyColor2Hex = [TungCommonObjects UIColorToHexString:keyColor2];
//    NSLog(@"key color 1: %@", [TungCommonObjects UIColorToHexString:keyColor1]);
//    NSLog(@"key color 2: %@", [TungCommonObjects UIColorToHexString:keyColor2]);
    if (podcastEntity) {
        podcastEntity.keyColor1Hex = keyColor1Hex;
        podcastEntity.keyColor2Hex = keyColor2Hex;
    }
    else {
        episodeEntity.podcast.keyColor1Hex = keyColor1Hex;
        episodeEntity.podcast.keyColor2Hex = keyColor2Hex;
    }
    
    // large button
    self.largeButton.color = keyColor2;
    [self setUpLargeButtonForEpisode:episodeEntity orPodcast:podcastEntity];
    
    // title, subtitle, desc
    [self sizeAndSetTitleForText:title];
    self.subTitleLabel.text = subTitle;
    self.descriptionLabel.text = desc;
    
    // key colors
    UIColor *lighterKeyColor = [TungCommonObjects lightenKeyColor:keyColor1];
    self.view.backgroundColor = lighterKeyColor;
    
    // subscribe button
    self.subscribeButton.type = kCircleTypeSubscribe;
    self.subscribeButton.color = keyColor2;
    self.subscribeButton.subscribed = isSubscribed;
    self.subscribeButton.hidden = NO;
    [self.subscribeButton setNeedsDisplay]; // re-display for color change or sub. status
    
    
    [self adjustHeaderViewHeightForContent];
}

- (void) setUpLargeButtonForEpisode:(EpisodeEntity *)episodeEntity orPodcast:(PodcastEntity *)podcastEntity {
    
    //NSString *defaultText = @"🎩✨";
    //NSString *defaultSubtitle = @"Magic";
    //NSLog(@"set up large button for episode or podcast");
    if (podcastEntity) {
        self.largeButton.hidden = YES;
        /*
        self.largeButton.type = kCircleTypeMagic;
        if (podcastEntity.buttonText) {
            self.largeButton.buttonText = podcastEntity.buttonText;
            self.largeButton.buttonSubtitle = podcastEntity.buttonSubtitle;
            self.largeButton.hidden = NO;
        } else {
            if (podcastEntity.hideMagicButton.boolValue) {
                self.largeButton.hidden = YES;
            } else {
                self.largeButton.buttonText = defaultText;
                self.largeButton.buttonSubtitle = defaultSubtitle;
                self.largeButton.hidden = NO;
            }
        }*/
    }
    else {
        self.largeButton.hidden = NO;
        self.largeButton.type = kCircleTypePlay;
        self.largeButton.on = NO;
        if (episodeEntity.isNowPlaying.boolValue) {
            self.largeButton.on = YES;
        }
        /*
        if (episodeEntity.isNowPlaying.boolValue) {
            self.largeButton.type = kCircleTypeMagic;
            if (episodeEntity.podcast.buttonText) {
                self.largeButton.buttonText = podcastEntity.buttonText;
                self.largeButton.buttonSubtitle = podcastEntity.buttonSubtitle;
                self.largeButton.on = NO;
            } else {
                if (episodeEntity.podcast.hideMagicButton.boolValue) {
                    self.largeButton.hidden = YES;
                } else {
                    self.largeButton.buttonText = defaultText;
                    self.largeButton.buttonSubtitle = defaultSubtitle;
                    self.largeButton.hidden = NO;
                }
            }
        } else {
            self.largeButton.type = kCircleTypePlay;
            self.largeButton.on = NO;
        }
         */
    }
    
    [self.largeButton setNeedsDisplay];
}



- (NSString *) getSubtitleLabelTextForEntity:(EpisodeEntity *)episodeEntity {
    if (episodeEntity.duration && episodeEntity.duration.length) {
        return [NSString stringWithFormat:@"%@  •  %@", [airDateFormatter stringFromDate:episodeEntity.pubDate], episodeEntity.duration];
    } else {
        return [airDateFormatter stringFromDate:episodeEntity.pubDate];
    }
}

- (void) constrainHeaderViewInViewController:(UIViewController *)vc {
    
    if (!self.isConstrained) {
        
        _viewController = vc;
        
        CGFloat topConstraint = 0;
        if ([vc isKindOfClass:[EpisodeViewController class]]) topConstraint = 64;
        /* reason for using conditional top contstraint:
         - in EpisodeViewController, without edgesForExtendedLayout prop, headerView sits under nav bar
         - with edgesForExtendedLayout, when searching from EVC then unwinding to it causes momentary gap at top
         */
        
        self.translatesAutoresizingMaskIntoConstraints = NO;
        [vc.view addConstraint:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:vc.view attribute:NSLayoutAttributeTop multiplier:1 constant:topConstraint]];
        [vc.view addConstraint:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:vc.view attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
        //[vc.view addConstraint:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:vc.view attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
        self.heightConstraint = [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:164];
        [vc.view addConstraint:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:vc.view.frame.size.width]];
        [self addConstraint:self.heightConstraint];
        self.isConstrained = YES;
        
        [vc.view layoutIfNeeded];
    }
    
}

- (void) adjustHeaderViewHeightForContent {
    
    if (self.isConstrained) {
        
        //NSLog(@"constrain header view");
    
        // size labels
        CGSize titleLabelSize = self.titleLabel.frame.size;
        self.titleLabel.preferredMaxLayoutWidth = titleLabelSize.width;
        [self.titleLabel sizeToFit];
        //NSLog(@"-- header view title label size: %@", NSStringFromCGRect(self.titleLabel.frame));
        
        CGSize subTitleLabelSize = self.subTitleLabel.frame.size;
        self.subTitleLabel.preferredMaxLayoutWidth = subTitleLabelSize.width;
        [self.subTitleLabel sizeToFit];
        //NSLog(@"-- subtitle label size: %@", NSStringFromCGRect(self.subTitleLabel.frame));
        
        CGFloat margin = 12;
        CGFloat maxDescWidth = [TungCommonObjects screenSize].width - margin - margin;
        self.descriptionLabel.preferredMaxLayoutWidth = maxDescWidth;
        [self.descriptionLabel sizeToFit];
        //NSLog(@"-- description label size: %@", NSStringFromCGRect(self.descriptionLabel.frame));
        
        // header height
        float height = margin + margin; // top and bottom margin
        height += self.titleLabel.frame.size.height;
        height += self.subTitleLabel.frame.size.height; // label heights
        height += 10 + 62; // between label and sub btn, sub btn height
        if (self.descriptionLabel.text.length)
            height += self.descriptionLabel.frame.size.height + 7; // top margin and desc label height
        //NSLog(@"-- FINAL HEIGHT: %f", height);
        
        self.heightConstraint.constant = height;
        [_viewController.view layoutIfNeeded];
    }
}

- (void) refreshHeaderViewForEntity:(PodcastEntity *)podcastEntity {
    // update image
    NSData *artImageData = [TungCommonObjects retrievePodcastArtDataForEntity:podcastEntity defaultSize:YES];
    UIImage *artImage = [[UIImage alloc] initWithData:artImageData];
    _albumArt.image = artImage;
    // update key colors
    _largeButton.color = (UIColor *)podcastEntity.keyColor2;
    [_largeButton setNeedsDisplay];
    _subscribeButton.color = (UIColor *)podcastEntity.keyColor2;
    [_subscribeButton setNeedsDisplay];
    
    UIColor *lighterKeyColor = [TungCommonObjects lightenKeyColor:(UIColor *)podcastEntity.keyColor1];
    _view.backgroundColor = lighterKeyColor;
    [self setNeedsDisplay];
}

@end
