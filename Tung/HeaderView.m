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

// for quicker display of episode view header,
// stop gap while waiting for episode info to establish episode entity
-(void) setUpHeaderViewForEpisodeMiniDict:(NSDictionary *)miniDict {
    
    self.hidden = NO;
    self.clipsToBounds = YES;
    
    // title
    NSString *title = [miniDict objectForKey:@"title"];
    if (title.length > 60) {
        self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightLight];
    }
    else {
        self.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightLight];
    }
    self.titleLabel.text = title;
    self.subTitleLabel.text = @"";
    self.descriptionLabel.text = @"";
    
    // art image
    NSString *artUrlString = [miniDict objectForKey:@"artworkUrlSSL"];
    NSData *artImageData = [TungCommonObjects retrieveSSLPodcastArtDataWithUrlString:artUrlString];
    UIImage *artImage = [[UIImage alloc] initWithData:artImageData];
    self.albumArt.image = artImage;
    
    UIColor *keyColor = [TungCommonObjects colorFromHexString:[miniDict objectForKey:@"keyColor1Hex"]];
    UIColor *lighterKeyColor = [TungCommonObjects lightenKeyColor:keyColor];
    self.view.backgroundColor = lighterKeyColor;
    
    // hide buttons until we get entity
    self.largeButton.hidden = YES;
    self.subscribeButton.hidden = YES;
    
}


static NSDateFormatter *airDateFormatter = nil;

-(void) setUpHeaderViewForEpisode:(EpisodeEntity *)episodeEntity orPodcast:(PodcastEntity *)podcastEntity {
    
    self.hidden = NO;
    self.clipsToBounds = YES;
    
    NSString *title, *subTitle, *desc;
    BOOL isSubscribed;
    NSData *artImageData;
    
    if (podcastEntity) {
        title = podcastEntity.collectionName;
        NSString *artist = [podcastEntity.artistName stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        subTitle = artist;
        desc = @"Loading feed...";
        if (title.length > 60) {
            self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightLight];
        }
        else if (title.length > 30) {
            self.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightLight];
        }
        else if (title.length > 17) {
            self.titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightLight];
        }
        
        artImageData = [TungCommonObjects retrievePodcastArtDataWithUrlString:podcastEntity.artworkUrl600 andCollectionId:podcastEntity.collectionId];
        
        isSubscribed = podcastEntity.isSubscribed.boolValue;
        
    }
    else {
        title = episodeEntity.title;
        if (!airDateFormatter) {
            airDateFormatter = [[NSDateFormatter alloc] init];
            [airDateFormatter setDateFormat:@"MMMM d, yyyy"];
        }
        subTitle = [airDateFormatter stringFromDate:episodeEntity.pubDate];
        desc = @"";
        if (title.length > 60) {
            self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightLight];
        }
        else {
            self.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightLight];
        }
        
        artImageData = [TungCommonObjects retrievePodcastArtDataWithUrlString:episodeEntity.podcast.artworkUrl600 andCollectionId:episodeEntity.collectionId];
        
        isSubscribed = episodeEntity.podcast.isSubscribed.boolValue;
        
    }
    
    // art image
    UIImage *artImage = [[UIImage alloc] initWithData:artImageData];
    self.albumArt.image = artImage;
    
    // find key color
    _keyColors = [TungCommonObjects determineKeyColorsFromImage:artImage];
    UIColor *keyColor1 = [_keyColors objectAtIndex:0];
    UIColor *keyColor2 = [_keyColors objectAtIndex:1];
    
    // play button
    if (podcastEntity) {
        //NSLog(@"set up header view for podcast");
        self.largeButton.hidden = YES;
    } else {
        //NSLog(@"set up header view for episode entity %@", [TungCommonObjects entityToDict:episodeEntity]);
        self.largeButton.hidden = NO;
        self.largeButton.type = kCircleTypePlay;
        if (episodeEntity.isNowPlaying.boolValue) {
            self.largeButton.on = YES;
        } else {
            self.largeButton.on = NO;
        }
    }
    self.largeButton.color = keyColor2;
    [self.largeButton setNeedsDisplay];
    
    self.titleLabel.text = title;
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
    
}

-(void) sizeAndConstrainHeaderViewInViewController:(UIViewController *)vc {
    
    //NSLog(@"size and constrain header view");
    
    // size labels
    CGSize titleLabelSize = self.titleLabel.frame.size;
    self.titleLabel.preferredMaxLayoutWidth = titleLabelSize.width;
    [self.titleLabel sizeToFit];
    
    CGSize subTitleLabelSize = self.subTitleLabel.frame.size;
    self.subTitleLabel.preferredMaxLayoutWidth = subTitleLabelSize.width;
    [self.subTitleLabel sizeToFit];
    
    CGFloat margin = 12;
    CGFloat maxDescWidth = vc.view.frame.size.width - margin - margin;
    self.descriptionLabel.preferredMaxLayoutWidth = maxDescWidth;
    [self.descriptionLabel sizeToFit];
    
    // header height
    float height = margin + margin; // top and bottom margin
    height += self.titleLabel.frame.size.height;
    height += self.subTitleLabel.frame.size.height; // label heights
    height += 16 + 62; // between label and sub btn, sub btn height
    height += self.descriptionLabel.frame.size.height + 7; // top margin and desc label height
    
    if (!self.isConstrained) {
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
        self.heightConstraint = [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:height];
        [vc.view addConstraint:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:vc.view.frame.size.width]];
        [self addConstraint:self.heightConstraint];
        self.isConstrained = YES;
    }
    
    self.heightConstraint.constant = height;
    [vc.view layoutIfNeeded];
}

@end
