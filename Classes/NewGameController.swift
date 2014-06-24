//
//  NewGameController.swift
//  LinkSame
//
//  Created by Matt Neuburg on 6/22/14.
//
//

import UIKit

class NewGameController : UIViewController {
    weak var tableView : UITableView!
    
    init () {
        super.init(nibName: nil, bundle: nil)
    }
    
    override func loadView() {
        let v = UIView()
        let tv = UITableView(frame:CGRectMake(0,0,320,400), style:.Grouped)
        v.addSubview(tv)
        tv.dataSource = self
        tv.delegate = self
        tv.bounces = false
        tv.scrollEnabled = false
        tv.reloadData()
        tv.sizeToFit()
        self.tableView = tv
        
        let pv = UIPickerView(frame:CGRectMake(0,0,320,160))
        pv.dataSource = self
        pv.delegate = self
        pv.reloadAllComponents()
        pv.sizeToFit()
        pv.frame.origin.y = tv.frame.size.height
        v.bounds = CGRectMake(0,0,320, tv.frame.size.height + pv.frame.size.height)
        v.addSubview(pv)
        pv.showsSelectionIndicator = true
        pv.selectRow(ud.integerForKey(Default.kStages), inComponent: 0, animated: false)
        self.view = v
        self.preferredContentSize = self.view.bounds.size
        println(self.preferredContentSize)
        //self.modalInPopover = true
    }
    
    override func shouldAutorotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation) -> Bool {
        return true
    }
}

extension NewGameController : UITableViewDataSource, UITableViewDelegate {
    func numberOfSectionsInTableView(tableView: UITableView!) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView!, titleForHeaderInSection section: Int) -> String! {
        switch section {
        case 0:
            return Default.kSize
        case 1:
            return Default.kStyle
        default:
            return nil
        }
    }
    
    func tableView(tableView: UITableView!, titleForFooterInSection section: Int) -> String! {
        return nil
    }
    
    func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 3
        case 1:
            return 2
        default:
            return 0
        }
    }

    func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell! {
        let cellId = "Cell"
        var cell : UITableViewCell! = tableView.dequeueReusableCellWithIdentifier(cellId) as? UITableViewCell
        if (!cell) {
            cell = UITableViewCell(style:.Default, reuseIdentifier:cellId)
        }
        
        let section = indexPath.section
        let row = indexPath.row
        
        switch section {
        case 0:
            cell.textLabel.text = Sizes.sizes()[row]
        case 1:
            cell.textLabel.text = Styles.styles()[row]
        default:
            cell.textLabel.text = "" // throwaway
        }
        
        cell.accessoryType = .None
        if ud.stringForKey(Default.kStyle) == cell.textLabel.text || ud.stringForKey(Default.kSize) == cell.textLabel.text {
            cell.accessoryType = .Checkmark
        }
        
        return cell
    }

    func tableView(tableView: UITableView!, didSelectRowAtIndexPath indexPath: NSIndexPath!) {
        let setting = tableView.cellForRowAtIndexPath(indexPath).textLabel.text
        ud.setObject(setting, forKey: self.tableView(tableView, titleForHeaderInSection:indexPath.section))
        self.tableView.reloadData()
    }
}

extension NewGameController : UIPickerViewDelegate, UIPickerViewDataSource {
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView!) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView!, numberOfRowsInComponent component: Int) -> Int {
        return 9
    }
    
    func pickerView(pickerView: UIPickerView!, titleForRow row: Int, forComponent component: Int) -> String! {
        return "\(row+1) Stage" + ( row > 0 ? "s" : "")
    }
    
    func pickerView(pickerView: UIPickerView!, didSelectRow row: Int, inComponent component: Int) {
        ud.setObject(row, forKey:Default.kStages)
    }
    
    func pickerView(pickerView: UIPickerView!, rowHeightForComponent component: Int) -> CGFloat {
        return 25
    }



}
