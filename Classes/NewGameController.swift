

import UIKit
import Swift

fileprivate let cellid = "Cell"

class NewGameController : UIViewController {
    weak var tableView : UITableView!
    
    init () {
        super.init(nibName: nil, bundle: nil)
        self.edgesForExtendedLayout = []
    }
    
    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()

        let v = self.view
        v?.backgroundColor = UIColor.white
        
        // unfortunately I have not found any way except to size manually like this by experimentation
        let tableHeight : CGFloat = (onPhone ? 120 : 300)
        let tv = UITableView(frame:CGRect(x: 0,y: 0,width: 320,height: tableHeight), style:.grouped)
        
        v?.addSubview(tv)
        tv.dataSource = self
        tv.delegate = self
        tv.bounces = false
        tv.isScrollEnabled = false
        tv.register(UITableViewCell.self, forCellReuseIdentifier: cellid)
        self.tableView = tv
        tv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            NSLayoutConstraint.constraints(withVisualFormat: "H:|[tv]|", options: [], metrics: nil, views: ["tv":tv]),
            NSLayoutConstraint.constraints(withVisualFormat: "V:|-(0)-[tv(tableHeight)]", options: [],
                metrics: ["tableHeight":tableHeight],
                views: ["tv":tv])
            ].flatMap{$0})
        
        let pv = UIPickerView()
        pv.translatesAutoresizingMaskIntoConstraints = false
        pv.dataSource = self
        pv.delegate = self
        v?.addSubview(pv)
        NSLayoutConstraint.activate([
            NSLayoutConstraint.constraints(withVisualFormat: "H:|[pv]|", options: [], metrics: nil, views: ["pv":pv]),
            NSLayoutConstraint.constraints(withVisualFormat: "V:[tv]-(0)-[pv]", options: [],
                metrics: nil,
                views: ["tv":tv, "pv":pv])
            ].flatMap{$0})
        pv.showsSelectionIndicator = true
        pv.selectRow(ud.integer(forKey: Default.lastStage), inComponent: 0, animated: false)

        self.preferredContentSize = CGSize(width: 320, height: tv.frame.size.height + pv.frame.size.height)
    }
}

extension NewGameController : UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return onPhone ? 1 : 2 // on iPhone, omit second (Size) section: there is just one size
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return Default.style
        case 1:
            return Default.size
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 2
        case 1:
            return 3
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellid, for:indexPath)
        
        let section = indexPath.section
        let row = indexPath.row
        
        switch section {
        case 0:
            cell.textLabel!.text = Styles.styles()[row]
        case 1:
            cell.textLabel!.text = Sizes.sizes()[row]
        default:
            cell.textLabel!.text = "" // throwaway
        }
        
        cell.accessoryType = .none
        let currentDefaults = [ud.string(forKey: Default.style), ud.string(forKey: Default.size)]
        if currentDefaults.contains(where: {$0 == cell.textLabel!.text}) {
            cell.accessoryType = .checkmark
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let setting = tableView.cellForRow(at: indexPath)?.textLabel?.text {
            ud.set(setting, forKey: self.tableView(tableView, titleForHeaderInSection:indexPath.section)!)
            self.tableView.reloadData()
        }
    }
}

extension NewGameController : UIPickerViewDelegate, UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 9
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return "\(row+1) Stage" + ( row > 0 ? "s" : "")
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        ud.set(row, forKey:Default.lastStage)
    }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 35
    }



}
