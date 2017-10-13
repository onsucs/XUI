//
//  XUIListViewController+XUITextareaCell.m
//  XXTExplorer
//
//  Created by Zheng Wu on 29/09/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import "XUIListViewController+XUITextareaCell.h"
#import "XUICellFactory.h"

@implementation XUIListViewController (XUITextareaCell)

- (void)tableView:(UITableView *)tableView XUITextareaCell:(UITableViewCell *)cell {
    XUITextareaCell *textareaCell = (XUITextareaCell *)cell;
    XUITextareaViewController *textareaViewController = [[XUITextareaViewController alloc] initWithCell:textareaCell];
    textareaViewController.cellFactory.theme = self.cellFactory.theme;
    textareaViewController.cellFactory.adapter = self.cellFactory.adapter;
    textareaViewController.delegate = self;
    textareaViewController.title = textareaCell.xui_label;
    [self.navigationController pushViewController:textareaViewController animated:YES];
}

#pragma mark - XUITextareaViewControllerDelegate

- (void)textareaViewControllerTextDidChanged:(XUITextareaViewController *)controller {
    [self storeCellWhenNeeded:controller.cell];
}

@end
