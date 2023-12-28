#!/bin/bash

STACK=$1
OPERATION=$2


# Function to check and return stack status
get_stack_status(stack) {
    aws cloudformation describe-stacks --stack-name $stack --query "Stacks[0].StackStatus" --output text 2>/dev/null
}


# Function to check stack creation status
check_stack_status(stack_name) {
    echo "Checking the status of stack $stack_name..."
    while true; do
        status=$(aws cloudformation describe-stacks --stack-name $stack_name --query "Stacks[0].StackStatus" --output text)
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




#perform operations on network stack
handle_network_stack(operation){
    manage_stack("network",$operation,"network.yml","network-parameters.json")
    # update network paramters for udagram if necessary
    # if [[ ! "$operation" =~ ^(CREATE|UPDATE)$ ]]; then
        
    #     echo "Exporting network stack outputs to JSON file..."
    #     aws cloudformation describe-stacks --stack-name "network" --query "Stacks[0].Outputs" > udagram-parameters.json
    # fi
}

# perform operation on udagram stack
handle_udagram_stack(operation){
   manage_stack("udagram",$operation,"network-parameters.json")
}

# Function to manage a specific stack
manage_stack(stackname,operation,stack_file_path,parameters_file_path) {
    
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
    echo "Usage: $0 [NETWORK|UDAGRAM|BOTH] [CREATE|UPDATE|DESTROY]"
    exit 1
fi

if [[ ! "$OPERATION" =~ ^(CREATE|UPDATE|DESTROY)$ ]]; then
    echo "Invalid choice for Operation"
    echo "Usage: $0 [NETWORK|UDAGRAM|BOTH] [CREATE|UPDATE|DESTROY]"
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
