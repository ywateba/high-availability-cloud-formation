#!/bin/bash
#set -e


STACK=$1
OPERATION=$2

NETWORK_STACK_NAME="NETWORK"
UDAGRAM_STACK_NAME="UDAGRAM"
NETWORK_STACK_PATH="network.yml"
NETWORK_PARAMETERS_PATH="network-parameters.json"
NETWORK_OUTPUTS_PATH="network-outputs.json"
UDAGRAM_STACK_PATH="uda.yml"
UDAGRAM_PARAMETERS_PATH="udagram-parameters.json"
UDAGRAM_OUTPUTS_PATH="udagram-outputs.json"



# Function to check and return stack status - no waiting
get_stack_status() {
    local stack_name=$1
    aws cloudformation describe-stacks --stack-name $stack_name --query "Stacks[0].StackStatus" --output text 2>/dev/null
    
}

# Function to check and return stack status with waiting
check_stack_status() {
    local stack_name=$1
    echo "Checking the status of stack $stack_name..."
    while true; do
        status=$(get_stack_status $stack_name)
        
        case $status in
        "CREATE_COMPLETE")
            echo "Stack $stack_name created successfully."
            break
            ;;
        "ROLLBACK_COMPLETE" | "CREATE_FAILED")
            echo "Stack $stack_name creation failed."
            break
            ;;
        "CREATE_IN_PROGRESS" | "UPDATE_IN_PROGRESS")
            echo "Creation or update  in progress..."
            sleep 10
            ;;
        "DELETE_IN_PROGRESS")
            echo "Delete  in progress..."
            sleep 10
            ;;

        *)
            echo "Stack does not exists or has been deleted"
            break
            ;;
        esac
        
    done
}


# Function to get stack outputs 
get_stack_outputs(){
    local stack_name=$1
    aws cloudformation describe-stacks --stack-name $stack_name --query "Stacks[0].Outputs" 2>/dev/null 
}


#format outputs and save in to a file
format_outputs(){
    local stack_name=$1
    local output_path=$2
    outputs=$(get_stack_outputs $stack_name)
    echo "$outputs" | jq  '[ .[] | {ParameterKey: .OutputKey, ParameterValue: .OutputValue} ]'  > "$output_path"
}


# Function to manage a specific stack - create , update or delete
# w.r.t to stack current status
manage_stack() {
    local stack_name=$1
    local operation=$2
    local stack_file_path=$3
    local parameters_file_path=$4
    local output_path=$5

    
    status=$(get_stack_status $stack_name)
    if [ -z "$status" ]; then
        echo "The network stack $stack_name does not exist or has been  deleted." 
        status="NON_EXISTENT"
    fi

    if [ "$operation" == "CHECK" ]; then
        echo "Status of  $stack_name: $status."
        if [[ "$status" == "CREATE_COMPLETE" ]] || [[ "$status" == "UPDATE_COMPLETE" ]]; then
            echo "Exporting network stack outputs to JSON file..." 
            format_outputs $stack_name $output_path
        fi
    fi
    
    case $status in
    "CREATE_COMPLETE" | "UPDATE_COMPLETE")
        if [ "$operation" == "UPDATE" ]; then
            echo "Updating stack $stack_name..."
            aws cloudformation update-stack --stack-name $stack_name \
                                            --template-body file://$stack_file_path \
                                            --parameters file://$parameters_file_path \
                                            --capabilities CAPABILITY_NAMED_IAM

        elif [ "$operation" == "DELETE" ]; then
            echo "Deleting stack $stack_name..."
            aws cloudformation delete-stack --stack-name $stack_name
        else
            echo "Stack is already created. Choose UPDATE or DELETE."
        fi
        ;;
    "CREATE_IN_PROGRESS" | "UPDATE_IN_PROGRESS" | "DELETE_IN_PROGRESS")
        echo "Stack $stack_name is currently in progress. Please wait."
        ;;
    "DELETE_IN_PROGRESS")
        echo "Stack $stack_name is currently being deleted. Please wait."
        ;;
    "ROLLBACK_COMPLETE" | "CREATE_FAILED" | "NON_EXISTENT")
        echo "$operation"
        if [ "$operation" == "CREATE" ]; then
            echo "Creating stack $stack_name..."
            aws cloudformation create-stack --stack-name $stack_name \
                                            --template-body file://$stack_file_path \
                                            --parameters file://$parameters_file_path \
                                            --capabilities CAPABILITY_NAMED_IAM
        else
            echo "Stack is in a state that requires manual intervention or does not exist."
        fi
        ;;
    *)
        echo "Stack is in state: $status, manual intervention might be required."
        ;;
    esac
}



# Main script starts here
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 [NETWORK|UDAGRAM|BOTH] [CREATE|UPDATE|DELETE]"
    exit 1
fi

if [[ ! "$OPERATION" =~ ^(CREATE|UPDATE|DELETE|CHECK)$ ]]; then
    echo "Invalid choice for Operation"
    echo "Usage: $0 [NETWORK|UDAGRAM] [CREATE|UPDATE|DELETE|CHECK]"
    exit 1
fi


case $OPERATION in
    CREATE | UPDATE)
        if [[ "$STACK" == "$NETWORK_STACK_NAME" ]]; then
            echo "We are handling network stack"
            manage_stack "$NETWORK_STACK_NAME" "$OPERATION" "$NETWORK_STACK_PATH" "$NETWORK_PARAMETERS_PATH" "$NETWORK_OUTPUTS_PATH"

            check_stack_status $NETWORK_STACK_NAME
            status=$(get_stack_status $NETWORK_STACK_NAME)
            
            # update network parameters for udagram if necessary
            if [[ "$status" == "CREATE_COMPLETE" ]] || [[ "$status" == "UPDATE_COMPLETE" ]]; then
                
                echo "Exporting network stack outputs to JSON file..."
                format_outputs $NETWORK_STACK_NAME $NETWORK_OUTPUTS_PATH
            fi
        fi
        if [[ "$STACK" == "$UDAGRAM_STACK_NAME" ]]; then
            echo "We are handling udagram stack"
            # we check if network stack exists
            
            network_status=$(get_stack_status $NETWORK_STACK_NAME)
            echo "network status $network_status"
            if [ -z "$network_status" ]; then
                echo "The network stack $NETWORK_STACK_NAME does not exist or has been  deleted."
                echo "Make network stack available first"
                exit 1
            fi

            if [[ "$network_status" == "CREATE_COMPLETE" ]] || [[ "$network_status" == "UPDATE_COMPLETE" ]]; then
                echo "creating the UDAGRAM stack"
                manage_stack "$UDAGRAM_STACK_NAME" "$OPERATION" "$UDAGRAM_STACK_PATH" "$UDAGRAM_PARAMETERS_PATH" "$UDAGRAM_OUTPUTS_PATH"
                check_stack_status $UDAGRAM_STACK_NAME
                echo "Exporting UDAGRAM stack outputs to JSON file..."
                format_outputs $UDAGRAM_STACK_NAME $UDAGRAM_OUTPUTS_PATH
            fi
        fi
        
        ;;
    DELETE)
        if [[ "$STACK" == "$UDAGRAM_STACK_NAME" ]]; then
            echo "We are handling udagram stack"
            status=$(get_stack_status $UDAGRAM_STACK_NAME)
            if [[ "$status" == "CREATE_COMPLETE" ]] || [[ "status" == "UPDATE_COMPLETE" ]]; then
                echo "creating the UDAGRAM stack"
                manage_stack "$UDAGRAM_STACK_NAME" "$OPERATION" "$UDAGRAM_STACK_PATH" "$UDAGRAM_PARAMETERS_PATH" "$UDAGRAM_OUTPUTS_PATH"
                
            fi
            check_stack_status $UDAGRAM_STACK_NAME
        fi
        if [[ "$STACK" == "$NETWORK_STACK_NAME" ]]; then
            echo "We are deleting the whole infrastructure"
            echo "We are handling udagram stack"
            status=$(get_stack_status $UDAGRAM_STACK_NAME)
            if [[ "$status" == "CREATE_COMPLETE" ]] || [[ "status" == "UPDATE_COMPLETE" ]]; then
                echo "deleting the UDAGRAM stack"
                manage_stack "$UDAGRAM_STACK_NAME" "$OPERATION" "$UDAGRAM_STACK_PATH" "$UDAGRAM_PARAMETERS_PATH" "$UDAGRAM_OUTPUTS_PATH"
                check_stack_status $UDAGRAM_STACK_NAME
            fi
            check_stack_status $UDAGRAM_STACK_NAME
            
            
            network_status=$(get_stack_status $NETWORK_STACK_NAME)
            if [[ "$network_status" == "CREATE_COMPLETE" ]] || [[ "status" == "UPDATE_COMPLETE" ]]; then
                echo "deleting the NETWORK stack"
                manage_stack "$NETWORK_STACK_NAME" "$OPERATION" "$NETWORK_STACK_PATH" "$NETWORK_PARAMETERS_PATH" "$NETWORK_OUTPUTS_PATH"
                
            fi
            check_stack_status $NETWORK_STACK_NAME
        fi
    ;;
    CHECK)
        echo "We are checking stack $STACK"
        check_stack_status $STACK 
    ;;

    *)
        echo "Invalid stack option. Choose NETWORK, UDAGRAM."
        exit 1
        ;;
esac


