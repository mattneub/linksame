
// creates and interacts with the dialog in which the user asks for a new game
// some other class must actually display the dialog (as a popover, as it happens)

#import "NewGameController.h"

@interface NewGameController () <UITableViewDataSource, UITableViewDelegate, UIPickerViewDelegate, UIPickerViewDataSource> {
    
}
@property (nonatomic, weak) UITableView* tableView;
@end


@implementation NewGameController

#pragma mark -
#pragma mark View lifecycle

- (void) loadView {
    //UIView* v = [[UIView alloc] initWithFrame:CGRectMake(0,0,320,310+216+100)];
    UIView* v = [[UIView alloc] init];
    UITableView* tv = [[UITableView alloc] initWithFrame:CGRectMake(0,0,320,330) style:UITableViewStyleGrouped];
    [v addSubview:tv];
    tv.dataSource = self;
    tv.delegate = self;
    tv.bounces = NO;
    tv.scrollEnabled = NO;
    self.tableView = tv;
    //UIPickerView* pv = [[UIPickerView alloc] initWithFrame:CGRectMake(0,310,320,216)];
    // new, let the view picker size itself automatically;
    UIPickerView* pv = [[UIPickerView alloc] initWithFrame:CGRectMake(0,0,200,180)]; // suppress annoying error message about wrong height
    [pv sizeToFit];
    //NSLog(@"%f", pv.bounds.size.height);
    CGRect f = pv.frame;
    f.origin.y = tv.frame.size.height;
    pv.frame = f;
    // new, let the view size itself according to its subviews
    v.bounds = CGRectMake(0, 0, 320, tv.frame.size.height + pv.frame.size.height);
    [v addSubview:pv];
    pv.dataSource = self;
    pv.delegate = self;
    pv.showsSelectionIndicator = YES;
    [pv selectRow:[[NSUserDefaults standardUserDefaults] integerForKey:@"Stages"] 
      inComponent:0 animated:NO];
    self.view = v;
    self.contentSizeForViewInPopover = self.view.bounds.size;
    self.modalInPopover = YES;
     // ooooh, this was a leak! fixed
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Override to allow orientations other than the default portrait orientation.
    return YES;
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString* title = nil;
    if (section == 0)
        title = @"Size";
    if (section == 1)
        title = @"Style";
    return title;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if (section == 0)
        return 3;
    return 2;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableVieww cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableVieww dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    NSUInteger section = [indexPath section];
    NSUInteger row = [indexPath row];
    
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    
    if (section == 0) {
        // size
        if (row == 0) {
            cell.textLabel.text = @"Easy";
        } else if (row == 1) {
            cell.textLabel.text = @"Normal";
        } else if (row == 2) {
            cell.textLabel.text = @"Hard";
        }
    } else if (section == 1) {
        if (row == 0) {
            cell.textLabel.text = @"Animals";
        } else if (row == 1) {
            cell.textLabel.text = @"Snacks";
        }
    }
    cell.accessoryType = UITableViewCellAccessoryNone;
    if ([[ud valueForKey:@"Style"] isEqualToString:cell.textLabel.text] ||
        [[ud valueForKey:@"Size"] isEqualToString:cell.textLabel.text])
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    
    return cell;
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
//    NSUInteger section = [indexPath section];
//    NSUInteger row = [indexPath row];
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    /*
    if (section == 0) {
        // size
        if (row == 0) {
            [ud setValue: @"Easy" forKey: @"Size"];
        } else if (row == 1) {
            [ud setValue: @"Normal" forKey: @"Size"];
        } else if (row == 2) {
            [ud setValue: @"Hard" forKey: @"Size"];
        }
    } else if (section == 1) {
        if (row == 0) {
            [ud setValue: @"Animals" forKey: @"Style"];
        } else if (row == 1) {
            [ud setValue: @"Snacks" forKey: @"Style"];
        }
    }
    */
    NSString* setting = [tv cellForRowAtIndexPath:indexPath].textLabel.text;
    [ud setValue:setting forKey:[self tableView:tv titleForHeaderInSection:indexPath.section]];

    [self.tableView reloadData];
}

#pragma mark -
#pragma mark Picker view support


- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return [NSString stringWithFormat: @"%i Stage%@", row+1, (row > 0 ? @"s" : @"")];
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return 9;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    [[NSUserDefaults standardUserDefaults] setObject:@(row) forKey:@"Stages"];
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component {
    return 25.0;
}

@end

