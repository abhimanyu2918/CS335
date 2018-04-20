class Program {
	struct Type{
		int counter;
		int[100] array;
	};

	struct Type node;

	int main(){
		Print "----------------Struct Program--------------" + endl;
		Print "Enter Size of array: ";
		int n = scan();
		node.counter = n;
		
		char[3] arr;
		arr[0] = 'N';
		arr[1] = 'e';
		arr[2] = 'w';
		Print arr[0] + arr[1] + arr[2] + endl;

		for(int i=0;i<node.counter;i++){
			node.array[i] = i*i;
		}
		for(int i=0;i<n;i++){
			Print node.array[i] + endl;
		}
		return 0;
	}
}
