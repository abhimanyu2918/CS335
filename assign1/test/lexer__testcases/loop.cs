class Program{
    int main(){
	
	    int i,j,k,res;
	    for(res = 0, i=0; i < 10; i++){
		    for(j = 0; j < 10; j++){
			    for(k = 0; k < 10; k++){
				    res += 1;
			    }
		    }
	    }
        Print "res = " + res + endl;
    }
}
