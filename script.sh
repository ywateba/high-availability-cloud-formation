#!/bin/bash

STACK=$1
OPERATION=$2

NETWORK_STACK_NAME="NETWORK"
UDAGRAM_STACK_NAME="UDAGRAM"
NETWORK_PARAMETERS_PATH="network-parameters.json"
UDAGRAM_PARAMETERS_PATH="udagram-parameters.json"



# Function to check and return stack status - no waiting
get_stack_status() {
    local stack_name =$1
    aws cloudformation describe-stacks --stack-name $stack_name --query "Stacks[0].StackStatus" --output text 
}

# Function to check and return stack status with waiting
check_stack_status() {
    local stack_name = $1
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
            exit 1
            ;;
        *)
            echo "Waiting for stack $stack_name to be created..."
            sleep 10
            ;;
        esac
    done
}


# Function to get stack outputs in to a file
get_stack_outputs(){
    local stack_name = $1
    local output_path = $2
    aws cloudformation describe-stacks --stack-name $stack_name --query "Stacks[0].Outputs" > $output_path
}



#perform operations on network stack
handle_network_stack(){
    local operation = 1$
    manage_stack $NETWORK_STACK_NAME $operation $NETWORK_STACK_PATH $NETWORK_PARAMETERS_PATH
    # update network paramters for udagram if necessary
    if [[ ! "$operation" =~ ^(CREATE|UPDATE)$ ]]; then
        echo "Exporting network stack outputs to JSON file..."
        get_stack_outputs $NETWORK_STACK_NAME $UDAGRAM_PARAMETERS_PATH
    fi
}

# Perform operation on udagram stack - create , update or delete
# Do nothing if network stack does not exist 
handle_udagram_stack(operation){
    local operation = 1$

    # we check if network stack exists
    status=$(get_stack_status $NETWORK_STACK_NAME)
    echo "Current status of the network stack $stack_name: $status"

    if [[ ! "$status" =~ ^(CREATE_COMPLETE|UPDATE_COMPLETE)$ ]]; then
        manage_stack $UDAGRAM_STACK_NAME $operation $UDAGRAM_STACK_PATH $UDAGRAM_PARAMETERS_PATH
    elif
        echo "Make network stack available first"
    fi
   
}

# Function to manage a specific stack - create , update or delete
# w.r.t to stack current status
manage_stack() {
    local stack_name = $1
    local operation = $2
    local stack_file_path = $3
    local parameters_file_path = $4

    status=$(get_stack_status $stack_name)
    echo "Current status of the stack $stack_name: $status"

    case $status in
    "CREATE_COMPLETE" | "UPDATE_COMPLETE")
        if [ "$operation" == "UPDATE" ]; then
            echo "Updating stack $stack_name..."
            aws cloudformation update-stack --stack-name $stack_name --template-body file://$stack_file_path --parameters file://$parameters_file_path
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
    "ROLLBACK_COMPLETE" | "CREATE_FAILED" | "")
        if [ "$operation" == "CREATE" ]; then
            echo "Creating stack $stack_name..."
            aws cloudformation create-stack --stack-name $stack_name --template-body file://$stack_file_path --parameters file://$parameters_file_path
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

if [[ ! "$OPERATION" =~ ^(CREATE|UPDATE|DELETE)$ ]]; then
    echo "Invalid choice for Operation"
    echo "Usage: $0 [NETWORK|UDAGRAM|BOTH] [CREATE|UPDATE|DELETE]"
    exit 1
fi



case $STACK in
    NETWORK)
        handle_network_stack $OPERATION
        ;;
    UDAGRAM)
        handle_udagram_stack $OPERATION
    ;;
    BOTH)
        # If BOTH is selected, perform the operation on both NETWORK and UDAGRAM stacks
        handle_network_stack $OPERATION
        handle_udagram_stack $OPERATION
        ;;
    *)
        echo "Invalid stack option. Choose NETWORK, UDAGRAM, or BOTH."
        exit 1
        ;;
esac
