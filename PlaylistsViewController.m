//
//  PlaylistsViewController.m
//  Treble
//
//  Created by Donka Stoyanov on 8/1/16.
//  Copyright © 2016 Donka Stoyanov. All rights reserved.
//

#import "PlaylistsViewController.h"
#import "DataClass.h"
#import "ABMSoundCloudAPISingleton.h"
#import "Constants.h"
#import "PlaylistTableViewCell.h"
#import "SongTableViewCell.h"

@interface PlaylistsViewController () <UITableViewDataSource, UITableViewDelegate>
{
    NSArray *searchResults;
    NSMutableArray *tmpSelectedArr;
}
@property (nonatomic, strong) NSArray *play_list;
@property (nonatomic, strong) NSMutableArray *SPTtrack;
@property (nonatomic, strong) NSMutableArray *DZRplay_list;
@property (nonatomic, strong) NSMutableArray *DZRtrack;
@property (nonatomic, strong) NSMutableArray *AMtrack;
@property (nonatomic, retain) NSString *SPTUsername;

@property (nonatomic, strong) DZRObjectList *playlistsDZR;
@property (nonatomic, strong) DZRObjectList *tracksDZR;

@property (nonatomic, weak) IBOutlet UILabel *playlists;
@property (nonatomic, weak) IBOutlet UILabel *songs;

@property (nonatomic, weak) IBOutlet UIView *listView;
@property (nonatomic, weak) IBOutlet UIView *songView;

@property (nonatomic, weak) IBOutlet UIButton *searchBtn;

@property (nonatomic, weak) IBOutlet UITableView *tableView;

@end

@implementation PlaylistsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // UIConfigure
    [self configureUI];
    
    self.tableView.delegate = self;
    self.tableView.separatorColor = [UIColor clearColor];
    
    self.tableView.backgroundColor = [UIColor colorWithRed:(30/255.0) green:(41/255.0) blue:(49/255.0) alpha:1];
    
    self.DZRplay_list = [NSMutableArray new];
    self.DZRtrack = [NSMutableArray new];
    self.AMtrack = [NSMutableArray new];
    self.SPTtrack = [NSMutableArray new];
    tmpSelectedArr = [NSMutableArray new];
    self.searchDisplayController.searchBar.hidden = YES;
    [[UITextField appearanceWhenContainedIn:[UISearchBar class], nil] setTextColor:[UIColor blackColor]];
    
    NSString *provider = [[DataClass getInstance] getProvider];
    if ([provider isEqualToString:@"SC"]) {
        [self getSoundCloudPlaylists];
    }
    else if ([provider isEqualToString:@"SPT"]){
        [self getSpotifyPlaylists];
    }
    else if ([provider isEqualToString:@"AM"]){
        [self getAppleMusicPlaylists];
    }
    else{
        [self getDeezerPlaylists];
    }
    
    [DataClass getInstance].SCtrack = [NSMutableArray new];
}

#pragma mark Get Playlists from streaming services
- (void)getSoundCloudPlaylists{
    NSMutableArray *playlistArray = [[NSMutableArray alloc] init];
    
    [[ABMSoundCloudAPISingleton sharedManager].soundCloudPort requestPlaylistsWithSuccess:^(NSArray *playlists) {
        if (playlists) {
            for (NSDictionary *dict in playlists) {
                SoundCloudPlaylist *soundCloudPlaylist = [[SoundCloudPlaylist alloc] initWithDictionary:dict];
                [playlistArray addObject:soundCloudPlaylist];
            }
            
            self.play_list = playlistArray;
            [DataClass getInstance].SClist = playlistArray;
            
            [self.tableView reloadData];
            if ([self.play_list count] > 0) {
                for (SoundCloudPlaylist *list in self.play_list) {
                    [[DataClass getInstance].SCtrack addObjectsFromArray:list.tracks];
                }
            }
        }
    }
    failure:^(NSError *error) {
        if (error) {
        }
    }];
}

- (void)getSpotifyPlaylists{
    SPTAuth *auth = [SPTAuth defaultInstance];
    
    [SPTUser requestCurrentUserWithAccessToken:auth.session.accessToken callback:^(NSError *error, SPTUser * responseObj){
        if (!error) {
            self.SPTUsername = responseObj.canonicalUserName;
        }
        else{
            UIAlertController * alert=   [UIAlertController
                                          alertControllerWithTitle:@"Error!"
                                          message:@"There was an error while connecting Spotify server"
                                          preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction* ok = [UIAlertAction
                                 actionWithTitle:@"OK"
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction * action)
                                 {
                                     [alert dismissViewControllerAnimated:YES completion:nil];
                                     
                                 }];
            
            [alert addAction:ok];
            
            [self presentViewController:alert animated:YES completion:nil];
        }
    }];
    
    [SPTPlaylistList playlistsForUser:self.SPTUsername withAccessToken:auth.session.accessToken callback:^(NSError *error, id object){

        if (object) {
			[self getFullPlaylistPage:(SPTListPage *)object];
        }
    }];
}

- (void)getFullPlaylistPage:(SPTListPage *)lp {
    __block SPTListPage *listPage = lp;
    if (listPage.hasNextPage) {
        [listPage requestNextPageWithSession:[SPTAuth defaultInstance].session callback:^(NSError *error, SPTListPage *playlistPage) {
            if (error != nil) {
                NSLog(@"*** Getting playlist page got error: %@", error);
                return;
            }
            
            listPage = [listPage pageByAppendingPage:playlistPage];
            [self getFullPlaylistPage:listPage];
        }];
    }
    else {
        NSMutableArray *playlist = [[NSMutableArray alloc] init];
        [self convertPlaylists:listPage arrayOfPlaylistSnapshots:playlist positionInListPage:0];
    }
}

- (void)convertPlaylists:(SPTListPage *)playlistPage arrayOfPlaylistSnapshots:(NSMutableArray *)playlist positionInListPage:(NSInteger)position {
    
    SPTAuth *auth = [SPTAuth defaultInstance];
    
    if (playlistPage.items.count > position) {
        SPTPartialPlaylist *userPlaylist = playlistPage.items[position];
        
        [SPTPlaylistSnapshot playlistWithURI:userPlaylist.uri accessToken:auth.session.accessToken callback:^(NSError *error, SPTPlaylistSnapshot *playablePlaylist) {
            if (error != nil) {
                NSLog(@"*** Getting playlists got error: %@", error);
                return;
            }
            
            if(!playablePlaylist) {
                NSLog(@"PlaylistSnapshot from call back is nil");
                return;
            }
            
            [playlist addObject:playablePlaylist];
            [self convertPlaylists:playlistPage arrayOfPlaylistSnapshots:playlist positionInListPage:position + 1];
            
        }];
        self.play_list = playlist;
        //Save this playlist for showing this in the first tabbar screen
        [DataClass getInstance].SPTlist = playlist;
    }
    else {
        self.play_list = playlist;
        if ([self.play_list count] > 0) {
            
            DataClass *obj = [DataClass getInstance];
            obj.currentSpotifyPlaylist = self.play_list[0];
            
            for (SPTPlaylistSnapshot *list in self.play_list) {
                for (NSDictionary *songsDictionary in list.decodedJSONObject[@"tracks"][@"items"])
                    [self.SPTtrack addObject:[SPTTrack trackFromDecodedJSON:songsDictionary[@"track"] error:nil]];
                
// Marked by Donka 2016 08/17 02:48
//                [obj.spotifyAllTracks removeAllObjects];
//                obj.spotifyAllTracks = [NSMutableArray new];
//                [obj.spotifyAllTracks addObjectsFromArray:tracks];
//                self.SPTtrack = obj.spotifyAllTracks;
// Mark ended
            }
        }
    }
    [self.tableView reloadData];
}

- (IBAction)search:(id)sender{
    self.searchDisplayController.searchBar.hidden = NO;
    self.searchBtn.hidden = YES;
}

- (void)getAppleMusicPlaylists{

    MPMediaQuery *query = [MPMediaQuery playlistsQuery];
    NSMutableArray *playlists = [NSMutableArray arrayWithArray:[query collections]];
    
    self.play_list = playlists;
    [DataClass getInstance].AMlist = playlists;
    //Get apple music track
    for (MPMediaPlaylist *list in playlists) {
        for (MPMediaItem *item in list.items) {
            [self.AMtrack addObject:item];
        }
    }
    [self.tableView reloadData];
}

- (void)getDeezerPlaylists{
    [DZRUser objectWithIdentifier:@"me"
                   requestManager:[DZRRequestManager defaultManager]
                         callback:^(DZRObject *o, NSError *error) {
                             [o valueForKey:@"playlists"
                         withRequestManager:[DZRRequestManager defaultManager]
                                   callback:^(id value, NSError *error) {
                                       if (!error) {
                                           if ([value isKindOfClass:[DZRObjectList class]]) {
                                               self.playlistsDZR = [DataClass getInstance].allDeezerPlayList = (DZRObjectList *)value;
                                               
                                               for (int i =0; i < [self.playlistsDZR count]; i ++) {
                                                   [self.playlistsDZR objectAtIndex:(i)
                                                                        withManager:[DZRRequestManager defaultManager]
                                                                           callback:^(id obj, NSError *error) {
                                                                               [self.DZRplay_list addObject:obj];
                                                                               
                                                                               [(DZRPlaylist *)obj valueForKey:@"tracks"
                                                                              withRequestManager:[DZRRequestManager defaultManager]
                                                                                        callback:^(id val, NSError *error) {
                                                                                            if (!error) {
                                                                                                if ([val isKindOfClass:[DZRObjectList class]]) {
                                                                                                    
                                                                                                    for (DZRTrack *track in [[val valueForKey:@"buckets"][0] valueForKey:@"elements"]) {
                                                                                                        [self.DZRtrack addObject:track];
                                                                                                    }
                                                                                                }
                                                                                            }
                                                                                        }];

                                                                           }];
                                               }
                                              
                                               //Save Deezer playlist for showing first tabbar screen
                                               [DataClass getInstance].DElist = self.DZRplay_list;
                                               
                                               if ([(DZRObjectList *)value count] > 0) {
                                                   [self.playlistsDZR objectAtIndex:0
                                                                        withManager:[DZRRequestManager defaultManager]
                                                                           callback:^(id obj, NSError *error) {
                                                                               [DataClass getInstance].currentDeezerPlaylist = obj;
                                                                           }];
                                               }
                                               [self.tableView reloadData];
                                           }
                                       }
                                   }];
                         }];
}

#pragma mark TableView
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    NSInteger count = 0;
    
    if (tableView == self.searchDisplayController.searchResultsTableView){
        count = [searchResults count];
    }
    else{
        if (self.playlists.hidden == NO) {
            if ([[[DataClass getInstance] getProvider] isEqualToString:@"DE"]) {
                count = ([self.playlistsDZR count] > 0) ? [self.playlistsDZR count] : [self.playlistsDZR count];
            }
            else{
                count = [self.play_list count];
            }
        }
        else{
            if ([[[DataClass getInstance] getProvider] isEqualToString:@"DE"]) {
                count = ([self.DZRtrack count] > 0) ? [self.DZRtrack count] : [self.DZRtrack count];
            }
            else if([[[DataClass getInstance] getProvider] isEqualToString:@"SPT"]){
                count = self.SPTtrack.count;
            }
            else if([[[DataClass getInstance] getProvider] isEqualToString:@"SC"]){
                count = [[DataClass getInstance].SCtrack count];
            }
            else if([[[DataClass getInstance] getProvider] isEqualToString:@"AM"]){
                count = self.AMtrack.count;
            }
        }
    }
    return count;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    NSString *listCellID = @"listCell";
    NSString *songCellID = @"songCell";
    
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        if (self.playlists.hidden == NO) {
            PlaylistTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:listCellID];
            cell.model = (id)searchResults[indexPath.row];
            
            [cell refreshCellForIndexPath:indexPath];
            cell.backgroundColor = [UIColor clearColor];
            
            if ([tmpSelectedArr containsObject:indexPath])
            {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
            else
            {
                cell.accessoryType = UITableViewCellAccessoryNone;
                
            }
            
            return cell;
        }
        else{
            SongTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:songCellID];
            
            if ([[[DataClass getInstance] getProvider] isEqualToString:@"DE"]) {
                cell.model = (id)[self.DZRtrack objectAtIndex:indexPath.row];
            }
            else if ([[[DataClass getInstance] getProvider] isEqualToString:@"SPT"]){
                cell.model = (id)[self.SPTtrack objectAtIndex:indexPath.row];
            }
            else if ([[[DataClass getInstance] getProvider] isEqualToString:@"SC"]){
                cell.model = (id)[[DataClass getInstance].SCtrack objectAtIndex:indexPath.row];
            }
            else if ([[[DataClass getInstance] getProvider] isEqualToString:@"AM"]){
                cell.model = (id)[self.AMtrack objectAtIndex:indexPath.row];
            }
        
            [cell refreshCellForIndexPath:indexPath];
            cell.backgroundColor = [UIColor clearColor];
            
            if ([tmpSelectedArr containsObject:indexPath])
            {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
            else
            {
                cell.accessoryType = UITableViewCellAccessoryNone;
                
            }

            return cell;
        }
    }
    else{
        if (self.playlists.hidden == NO) {
            PlaylistTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:listCellID];
            
            if ([[[DataClass getInstance] getProvider] isEqualToString:@"DE"]) {
                [self.playlistsDZR objectAtIndex:(indexPath.row)
                                     withManager:[DZRRequestManager defaultManager]
                                        callback:^(id obj, NSError *error) {
                                            cell.model = obj;
                                        }];
            }
            else{
                cell.model = (id)self.play_list[indexPath.row];
            }
            
            [cell refreshCellForIndexPath:indexPath];
            cell.backgroundColor = [UIColor clearColor];
            
            if ([tmpSelectedArr containsObject:indexPath])
            {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
            else
            {
                cell.accessoryType = UITableViewCellAccessoryNone;
                
            }

            return cell;
        }
        else{
            SongTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:songCellID];
            
            if ([[[DataClass getInstance] getProvider] isEqualToString:@"DE"]) {
                cell.model = (id)[self.DZRtrack objectAtIndex:indexPath.row];
            }
            else if([[[DataClass getInstance] getProvider] isEqualToString:@"SPT"]){
                cell.model = (id)[self.SPTtrack objectAtIndex:indexPath.row];
            }
            else if([[[DataClass getInstance] getProvider] isEqualToString:@"SC"]){
                cell.model = (id)[[DataClass getInstance].SCtrack objectAtIndex:indexPath.row];
            }
            else if([[[DataClass getInstance] getProvider] isEqualToString:@"AM"]){
                cell.model = (id)[self.AMtrack objectAtIndex:indexPath.row];
            }
            
            [cell refreshCellForIndexPath:indexPath];
            cell.backgroundColor = [UIColor clearColor];
            
            if ([tmpSelectedArr containsObject:indexPath])
            {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
            else
            {
                cell.accessoryType = UITableViewCellAccessoryNone;
                
            }

            return cell;
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 90;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if ([tmpSelectedArr containsObject:indexPath]) {
            
        if (self.playlists.hidden == NO) {
//Marked by Donka 2016/08/10
//                if ([[[DataClass getInstance] getProvider] isEqualToString:@"DE"]) {
//                    [[DataClass getInstance].selectedArr removeObject:self.DZRplay_list[indexPath.row - 1]];
//                    [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryNone];
//                }
//                else{
//                    [[DataClass getInstance].selectedArr removeObject:self.play_list[indexPath.row - 1]];
//                    [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryNone];
//                }
//Mark ended
        }
        else{
            if ([[[DataClass getInstance] getProvider] isEqualToString:@"DE"]) {
                [[DataClass getInstance].selectedArr removeObject:self.DZRtrack[indexPath.row]];
                [tmpSelectedArr removeObject:indexPath];
                [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryNone];
            }
            else if ([[[DataClass getInstance] getProvider] isEqualToString:@"SPT"]){
                [[DataClass getInstance].selectedArr removeObject:self.SPTtrack[indexPath.row]];
                [tmpSelectedArr removeObject:indexPath];
                [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryNone];
            }
            else if ([[[DataClass getInstance] getProvider] isEqualToString:@"SC"]){
                [[DataClass getInstance].selectedArr removeObject:[DataClass getInstance].SCtrack[indexPath.row]];
                [tmpSelectedArr removeObject:indexPath];
                [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryNone];
            }
            else if ([[[DataClass getInstance] getProvider] isEqualToString:@"AM"]){
                [[DataClass getInstance].selectedArr removeObject:self.AMtrack[indexPath.row]];
                [tmpSelectedArr removeObject:indexPath];
                [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryNone];
            }
        }
    } else {
        
        if (self.playlists.hidden == NO) {
//Marked by Donka 2016/08/10
//                if ([[[DataClass getInstance] getProvider] isEqualToString:@"DE"]) {
//                    [[DataClass getInstance].selectedArr addObject:self.DZRplay_list[indexPath.row - 1]];
//                    [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
//                }
//                else{
//                    [[DataClass getInstance].selectedArr addObject:self.play_list[indexPath.row - 1]];
//                    [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
//                }
//Mark ended
        }
        else{
            if ([[[DataClass getInstance] getProvider] isEqualToString:@"DE"]) {
                [[DataClass getInstance].selectedArr addObject:self.DZRtrack[indexPath.row ]];
                [tmpSelectedArr addObject:indexPath];
                [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
            }
            else if ([[[DataClass getInstance] getProvider] isEqualToString:@"SPT"]){
                [[DataClass getInstance].selectedArr addObject:self.SPTtrack[indexPath.row]];
                [tmpSelectedArr addObject:indexPath];
                [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
            }
            else if ([[[DataClass getInstance] getProvider] isEqualToString:@"SC"]){
                [[DataClass getInstance].selectedArr addObject:[DataClass getInstance].SCtrack[indexPath.row]];
                [tmpSelectedArr addObject:indexPath];
                [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
            }
            else if ([[[DataClass getInstance] getProvider] isEqualToString:@"AM"]){
                [[DataClass getInstance].selectedArr addObject:self.AMtrack[indexPath.row]];
                [tmpSelectedArr addObject:indexPath];
                [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
            }
        }
    }

}

#pragma mark Configure UI
- (void)configureUI {
    self.playlists.hidden = NO;
    self.songs.hidden = YES;
    
    UITapGestureRecognizer *singleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                      action:@selector(listViewTap)];
    [self.listView addGestureRecognizer:singleFingerTap];
    
    UITapGestureRecognizer *singleFingerTap1 = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                       action:@selector(songViewTap)];
    [self.songView addGestureRecognizer:singleFingerTap1];
}

- (void)listViewTap {
    self.playlists.hidden = NO;
    self.songs.hidden = YES;
    [self.tableView reloadData];
}

- (void)songViewTap {
    self.playlists.hidden = YES;
    self.songs.hidden = NO;
    [self.tableView reloadData];
}

- (IBAction)back:(id)sender {
//Marked by Donka 2016 08/10 23:17
//  Think this is not necessary because I am going to make only tracks are selectable for organising own playlist
//    if (self.playlists.hidden == YES) {
//        [DataClass getInstance].current = @"Track";
//    }
//    else{
//        [DataClass getInstance].current = @"Playlist";
//    }
//Marked ended
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    UIViewController *vc = [storyboard instantiateViewControllerWithIdentifier:@"TabbarVC1"];
    
    [self presentViewController:vc animated:YES completion:nil];
}

#pragma mark Serach filter
- (void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
    if (self.playlists.hidden == NO) { //Playlist
        if ([[[DataClass getInstance] getProvider] isEqualToString:@"SPT"]) {
            NSPredicate *resultPredicate = [NSPredicate predicateWithFormat:@"name contains[c] %@", searchText];
            searchResults = [self.play_list filteredArrayUsingPredicate:resultPredicate];
        }
        else if ([[[DataClass getInstance] getProvider] isEqualToString:@"DE"]) {
            NSPredicate *resultPredicate = [NSPredicate predicateWithFormat:@"title contains[c] %@", searchText];
            searchResults = [self.DZRplay_list filteredArrayUsingPredicate:resultPredicate];
        }
        else if ([[[DataClass getInstance] getProvider] isEqualToString:@"SC"]) {
            NSPredicate *resultPredicate = [NSPredicate predicateWithFormat:@"title contains[c] %@", searchText];
            searchResults = [self.play_list filteredArrayUsingPredicate:resultPredicate];
        }
        else if ([[[DataClass getInstance] getProvider] isEqualToString:@"AM"]) {
            NSPredicate *resultPredicate = [NSPredicate predicateWithFormat:@"title contains[c] %@", searchText];
            searchResults = [self.play_list filteredArrayUsingPredicate:resultPredicate];
        }
    }
    else{ //Song
        if ([[[DataClass getInstance] getProvider] isEqualToString:@"SPT"]) {
            NSPredicate *resultPredicate = [NSPredicate predicateWithFormat:@"name contains[c] %@", searchText];
            searchResults = [self.SPTtrack filteredArrayUsingPredicate:resultPredicate];
        }
        else if ([[[DataClass getInstance] getProvider] isEqualToString:@"DE"]) {
            NSPredicate *resultPredicate = [NSPredicate predicateWithFormat:@"title contains[c] %@", searchText];
            searchResults = [self.DZRtrack filteredArrayUsingPredicate:resultPredicate];
        }
        else if ([[[DataClass getInstance] getProvider] isEqualToString:@"SC"]) {
            NSPredicate *resultPredicate = [NSPredicate predicateWithFormat:@"title contains[c] %@", searchText];
            searchResults = [[DataClass getInstance].SCtrack filteredArrayUsingPredicate:resultPredicate];
        }
        else if ([[[DataClass getInstance] getProvider] isEqualToString:@"AM"]) {
            NSPredicate *resultPredicate = [NSPredicate predicateWithFormat:@"title contains[c] %@", searchText];
            searchResults = [self.AMtrack filteredArrayUsingPredicate:resultPredicate];
        }
    }
}

-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self filterContentForSearchText:searchString
                               scope:[[self.searchDisplayController.searchBar scopeButtonTitles]
                                      objectAtIndex:[self.searchDisplayController.searchBar
                                                     selectedScopeButtonIndex]]];
    
    return YES;
}

- (void) searchDisplayControllerWillEndSearch:(UISearchDisplayController *)controller{
    self.searchDisplayController.searchBar.hidden = YES;
    self.searchBtn.hidden = NO;
}

@end
