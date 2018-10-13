

import UIKit
import Swift

private let cellid = "Cell"
private let headerid = "Header"

class NewGameController : UIViewController {
    weak var tableView : UITableView?
    
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
        
        // initial table height just an estimate, real height will be determined later
        let tableHeight : CGFloat = (onPhone ? 120 : 300)
        let tv = UITableView(frame:CGRect(x: 0,y: 0,width: 320,height: tableHeight), style:.plain)
        
        v?.addSubview(tv)
        tv.dataSource = self
        tv.delegate = self
        tv.bounces = false
        tv.isScrollEnabled = false
        tv.register(UITableViewCell.self, forCellReuseIdentifier: cellid)
        tv.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: headerid)
        self.tableView = tv
        tv.translatesAutoresizingMaskIntoConstraints = false
        
        let pv = UIPickerView()
        pv.translatesAutoresizingMaskIntoConstraints = false
        pv.dataSource = self
        pv.delegate = self
        v?.addSubview(pv)
        // no table height constraint yet
        NSLayoutConstraint.activate([
            NSLayoutConstraint.constraints(withVisualFormat: "H:|[tv]|", options: [], metrics: nil, views: ["tv":tv]),
            NSLayoutConstraint.constraints(withVisualFormat: "H:|[pv]|", options: [], metrics: nil, views: ["pv":pv]),
            NSLayoutConstraint.constraints(withVisualFormat: "V:[tv]-(0)-[pv]", options: [],
                metrics: nil,
                views: ["tv":tv, "pv":pv])
            ].flatMap{$0})
        pv.showsSelectionIndicator = true
        pv.selectRow(ud.integer(forKey: Default.lastStage), inComponent: 0, animated: false)

        self.preferredContentSize = CGSize(width: 320, height: tv.frame.size.height + pv.frame.size.height)
    }
    
    // determine actual table height constraint
    var didUpdateConstraints = false
    override func updateViewConstraints() {
        if !didUpdateConstraints {
            didUpdateConstraints = true
            var h : CGFloat = 0
            let tv = self.tableView!
            let secs = tv.numberOfSections
            for sec in 0..<secs {
                h += tv.rectForHeader(inSection: sec).height
                let rows = tv.numberOfRows(inSection: sec)
                for row in 0..<rows {
                    h += tv.rectForRow(at: IndexPath(row: row, section: sec)).height
                }
            }
            NSLayoutConstraint.activate([
                NSLayoutConstraint.constraints(withVisualFormat: "V:|-(0)-[tv(tableHeight)]", options: [],
                                               metrics: ["tableHeight":h],
                                               views: ["tv":tv])
                ].flatMap{$0})
        }
        super.updateViewConstraints()
    }
}

extension NewGameController : UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return onPhone ? 1 : 2 // on iPhone, omit second (Size) section: there is just one size
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let v = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerid)!
        if v.viewWithTag(99) == nil {
            let lab = UILabel()
            lab.tag = 99
            lab.font = UIFont.systemFont(ofSize: 20, weight: .bold)
            lab.translatesAutoresizingMaskIntoConstraints = false
            v.contentView.addSubview(lab)
            NSLayoutConstraint.activate([
                lab.topAnchor.constraint(equalTo: v.contentView.topAnchor),
                lab.bottomAnchor.constraint(equalTo: v.contentView.bottomAnchor),
                lab.leadingAnchor.constraint(equalTo: v.contentView.layoutMarginsGuide.leadingAnchor)
            ])
        }
        let lab = v.viewWithTag(99) as! UILabel
        lab.text = section == 0 ? Default.style : Default.size
        return v
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
        cell.textLabel?.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        
        cell.accessoryType = .none
        let currentDefaults = [ud.string(forKey: Default.style), ud.string(forKey: Default.size)]
        if currentDefaults.contains(where: {$0 == cell.textLabel!.text}) {
            cell.accessoryType = .checkmark
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let setting = tableView.cellForRow(at: indexPath)?.textLabel?.text {
            ud.set(setting, forKey: indexPath.section == 0 ? Default.style : Default.size)
            tableView.reloadData()
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
