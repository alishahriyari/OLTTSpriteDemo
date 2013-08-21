//
//  OLViewController.m
//  OLTTSpriteDemo
//
//  Created by Ali Shahriyari on 8/19/13.
//  Copyright (c) 2013 Originate. All rights reserved.
//

#import "OLViewController.h"
#import "OLMyScene.h"

@implementation OLViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Configure the view.
    SKView * skView = (SKView *)self.view;
    skView.showsFPS = YES;
    skView.showsNodeCount = YES;
    
    // Create and configure the scene (double the size to fit more into the view)
    CGSize viewSize = self.view.bounds.size;
    viewSize.height *= 2;
    viewSize.width *= 2;
  
    SKScene * scene = [OLMyScene sceneWithSize:viewSize];
    scene.scaleMode = SKSceneScaleModeAspectFill;
    
    // Present the scene.
    [skView presentScene:scene];
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    } else {
        return UIInterfaceOrientationMaskAll;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

@end
