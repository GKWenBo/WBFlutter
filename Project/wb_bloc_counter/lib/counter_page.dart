import 'package:flutter/material.dart';
import 'package:wb_bloc_counter/bloc/counter_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Counter")),
      body: BlocBuilder<CounterBloc, int>(
        builder: (context, count) {
          return Center(
            child: Text("$count", style: TextStyle(fontSize: 24.0)),
          );
        },
      ),
      floatingActionButton: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 5.0),
            child: FloatingActionButton(
              onPressed: () {
                context.read<CounterBloc>().add(CounterIncrementPressed());
              },
              child: Icon(Icons.add),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 5.0),
            child: FloatingActionButton(
              onPressed: () {
                context.read<CounterBloc>().add(CounterDecrementPressed());
              },
              child: Icon(Icons.remove),
            ),
          ),
        ],
      ),
    );
  }
}
