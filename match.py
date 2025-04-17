import os
import json

def find_bytecode_in_json_files(directory, filename_pattern):
    bytecode_list = []
    
    for root, dirs, files in os.walk(directory):
        for file in files:
            if filename_pattern in file and file.endswith('.json'):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    try:
                        data = json.load(f)
                        if 'bytecode' in data:
                            return data['bytecode']
                    except json.JSONDecodeError:
                        print(f"Error decoding JSON in file: {file_path}")
    
    raise ValueError("{} not found".format(filename_pattern))


def list_json_files(directory):
    json_files = []
    
    for item in os.listdir(directory):
        item_path = os.path.join(directory, item)
        if os.path.isfile(item_path) and item.endswith('Impl.json'):
            json_files.append(item)

    return json_files

def check(directory):
    names = list_json_files(directory)
    matched = True
    for name in names:
        b0 = ""
        with open(os.path.join(directory, name), 'r', encoding='utf-8') as f:
            try:
                data = json.load(f)
                if 'bytecode' in data:
                     b0 = data['bytecode']
                else:
                    raise ValueError("bytecode field not found for {}".format(name))
            except json.JSONDecodeError:
                print(f"Error decoding JSON in file: {name}")
        b1 = find_bytecode_in_json_files("./artifacts", name.replace("Impl.json", ".json"))
        if b0 != b1:
            print("[ERROR] {} bytecode is different, network: {}".format(name, directory.split('/')[-1]))
            matched = False
        else:
            print("{} bytecode matched, network: {}".format(name, directory.split('/')[-1]))
    if matched:
        print("network {} bytecode matched".format(directory.split('/')[-1]))

#check("./deployments/zgTestnetStandard")
check("./deployments/zgTestnetTurbo")
