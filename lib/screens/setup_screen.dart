import 'package:flutter/material.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const int maxPlayers = 12;
  static const int minUndercover = 1;
  int get maxUndercover => (playerNum / 2).ceil() - 1;
  int get minPlayers => (undercoverNum * 2) + 1;
  int playerNum = 4;
  int undercoverNum = 1;

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("设置"),

      ),
      body: Stack(
        children: [
          Column(
            children: [
              Row(
                children: [
                  Container(
                    child: Text("玩家数目"),
                  ),
                  TextButton(
                  onPressed: (){
                    setState(() {
                      if(playerNum > minPlayers) {
                        playerNum--;
                      }
                    });
                  }, 
                  child: Text("-")
                  ),
                  Container(
                    child: Text(playerNum.toString()),
                  ),
                  TextButton(
                  onPressed: (){
                    setState(() {
                      if(playerNum < maxPlayers) {
                        playerNum++;
                      }
                    });
                  }, 
                  child: Text("+")
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    child: Text("卧底数目"),
                  ),
                  TextButton(
                  onPressed: (){
                    setState(() {
                      if(undercoverNum > minUndercover) {
                        undercoverNum--;
                      }
                    });
                  }, 
                  child: Text("-")
                  ),
                  Container(
                    child: Text(undercoverNum.toString()),
                  ),
                  TextButton(
                  onPressed: (){
                    setState(() {
                      if(undercoverNum < maxUndercover) {
                        undercoverNum++;
                      }
                    });
                  }, 
                  child: Text("+")
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/host');
                },
                child: Text('开始游戏'),
              )
            ],
          )
        ],
      ),
    );
  }
}