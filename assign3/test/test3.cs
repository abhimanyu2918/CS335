 class Program{
	int a = 3;
	char c = 'E';
	bool[] arr1= {true, false, true};
		
	int func1(int arg1, int arg2){
		switch(arg1){
			case 1: Print "Not true" + endl;
					return -1;
			case 2: Print "You got it" + arg1 + endl;
					break;
			default: Print "False";
					 return 2;
		}

		return 1;

	}

	int main(){
		char localVar = 'W';
		int localVar2 = func1(a, 10);
		if(localVar2==1)
			Print "OK";
		else if(localVar2==2)	
			Print "Fine";
		else{
			Print "Not Ok";
		}
	return 0;
	}	
}
