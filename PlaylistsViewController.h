//
//  PlaylistsViewController.h
//  Treble
//
//  Created by Donka Stoyanov on 8/1/16.
//  Copyright © 2016 Donka Stoyanov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SoundCloudPort.h"
#import <Spotify/Spotify.h>
#import "DeezerConnect.h"
#import "DeezerSession.h"
#import "ABMSoundCloudAPISingleton.h"
#import "SoundCloudPlaylist.h"
#import "DZRUser.h"
#import "DZRRequestManager.h"
#import "DZRObjectList.h"
#import <MediaPlayer/MediaPlayer.h>
#import <Spotify/SPTYourMusic.h>

@interface PlaylistsViewController : UIViewController
@property (nonatomic, strong) SoundCloudPort *soundCloudPort;
@end
