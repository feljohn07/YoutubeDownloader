import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
// import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:external_path/external_path.dart';
import 'dart:io';

import 'dart:math';

import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;

class YoutubeDownloadPage extends StatefulWidget {

  const YoutubeDownloadPage({super.key});

  @override
  State<YoutubeDownloadPage> createState() => _YoutubeDownloadPage();
}

class _YoutubeDownloadPage extends State<YoutubeDownloadPage> {

  bool isLoading = false;

  String videoID = '';
  String videoUrl = '';
  String title = '';
  String description = '';

  String videoManifest = '';
  List choices = [];

  String downloadDirectory = '';
  String downloadPath = '';

  int progress = 0;

  @override
  void initState() {
    super.initState();
    
    initDownloadDirectory();

  }


  Future<void> initDownloadDirectory() async {

    try {
      String path = await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOWNLOADS);
      var downloadDir = await Directory('$path/Test').create(recursive: true);

      setState(() {
        downloadDirectory = downloadDir.path;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));

      try {
        final downloadDir = await getDownloadsDirectory();
        setState(() {
          downloadDirectory = p.join(downloadDir!.path, 'YoutubeDownloader');
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }

  }


  void viewVideoManifest() async {

    setState(() {
      isLoading = true;
    });

    final yt = YoutubeExplode();
    final video = await yt.videos.get(videoUrl);

    // Get the video manifest.
    final manifest = await yt.videos.streamsClient.getManifest(videoUrl);

    getVideoId(videoUrl);

    setState(() {
      title = video.title;
      description = video.description;
      videoManifest = manifest.toString();
      isLoading = false;
    });
  } 


  void viewChoices() async {

    final yt = YoutubeExplode();

    // Get the video manifest.
    final manifest = await yt.videos.streamsClient.getManifest(videoUrl);
    
    var list = manifest.audioOnly.iterator;

    while(list.moveNext()) {
      print(list.current.size);
    }

    // print(manifest.audioOnly);
    // print(manifest.audioOnly.length);
    // print(manifest.audioOnly.describe());
    // print(manifest.audioOnly.first);
    // print(manifest.audioOnly.last);
    // print(manifest.audioOnly.elementAt(1));

  }


  void getVideoId(String url) {
    try {

      setState(() {
        // videoID = YoutubePlayer.convertUrlToId(url)!;
      });

    } on Exception catch (exception) {

      // only executed if error is of type Exception
      print('exception $exception');

    } catch (error) {

      // executed for errors of all types other than Exception
      print('catch error');
      //  videoIdd="error";

    }
  }


  void downloadVideo() async {

    // ScaffoldMessenger.of(context).showSnackbar(Snackbar())
    
    final yt = YoutubeExplode();
    final video = await yt.videos.get(videoUrl);

    setState(() {
      title = video.title;
      description = video.description;
    });

    
    // Request permission to write in an external directory.
    // (In this case downloads)

    try {
      await Permission.storage.request();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }

    // Get the video manifest.
    final manifest = await yt.videos.streamsClient.getManifest(videoUrl);

    print(manifest);

    // Muxed
    final muxedStreams = manifest.muxed;

    // Get the muxed track with the highest bitrate.
    final muxed = muxedStreams.first;

    final muxedStream = yt.videos.streamsClient.get(muxed);

    // Compose the file name removing the unallowed characters in windows.
    final fileName = '${video.title}.${muxed.container.name}'
      .replaceAll(r'\', '')
      .replaceAll('/', '')
      .replaceAll('*', '')
      .replaceAll('?', '')
      .replaceAll('"', '')
      .replaceAll('<', '')
      .replaceAll('>', '')
      .replaceAll('|', '');

    // _showAlertDialog();


    final File file = File('$downloadDirectory/$fileName');

    try{
      // Delete the file if exists.
      if (file.existsSync()) {
        file.deleteSync();
      }

    }catch(error) {
      print(error);
    }

    final output = file.openWrite(mode: FileMode.writeOnlyAppend);


    // Track the file download status.
    final len = muxed.size.totalBytes;
    var count = 0;

    // Create the message and set the cursor position.
    final msg = 'Downloading ${video.title}.${muxed.container.name}';
    print(msg);

    // Downloading the file.
    await for (final data in muxedStream) {
      // Keep track of the current downloaded data.
      count += data.length;

      // Calculate the current progress and then display.
      setState(() {
        progress = ((count / len) * 100).ceil();
        print(progress);
      });

      // Write to file.
      output.add(data);
    }

    await output.close();

    // Close the YoutubeExplode's http client.
    yt.close();
    print('Downloading video from: $videoUrl');
  }


  void downloadAudio() async {

    final yt = YoutubeExplode();
    final video = await yt.videos.get(videoUrl);

    setState(() {
      title = video.title;
      description = video.description;
    });

    
    // Request permission to write in an external directory.
    // (In this case downloads)
    try {
      await Permission.storage.request();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }

    // Get the video manifest.
    final manifest = await yt.videos.streamsClient.getManifest(videoUrl);
    
    // print(manifest);

    // audioOnly
    final audioStreams = manifest.audioOnly;
    
    // Get the audio track with the highest bitrate.
    final audio = audioStreams.withHighestBitrate();

    final audioStream = yt.videos.streamsClient.get(audio);

    // Compose the file name removing the unallowed characters in windows.
    final fileName = '${video.title}${Random().nextInt(100)}.${audio.container.name}'
      .replaceAll(r'\', '')
      .replaceAll('/', '')
      .replaceAll('*', '')
      .replaceAll('?', '')
      .replaceAll('"', '')
      .replaceAll('<', '')
      .replaceAll('>', '')
      .replaceAll('|', '');

  
    File file = File('$downloadDirectory/$fileName');

    // Delete the file if exists.
    if (file.existsSync()) {
      file.deleteSync();
    }

    final output = file.openWrite(mode: FileMode.writeOnlyAppend);

    // Track the file download status.
    final len = audio.size.totalBytes;
    var count = 0;

    // Create the message and set the cursor position.
    final msg = 'Downloading ${video.title}.${audio.container.name}';
    print(msg);

    try{
      // Downloading the file.
      await for (final data in audioStream) {
        // Keep track of the current downloaded data.
        count += data.length;

        // Calculate the current progress and then display.
        setState(() {
          progress = ((count / len) * 100).ceil();
          print(progress);
        });

        // Write to file.
        output.add(data);
      }

      await output.close();

      // Close the YoutubeExplode's http client.
      yt.close();
      print('Downloading video from: $videoUrl');
    }catch(error){

      try {
        file.deleteSync();
      } catch (e) {
        ScaffoldMessenger.of(context).showMaterialBanner(MaterialBanner(content: Text(error.toString()), actions: [ElevatedButton(onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
        }, child: Text('okay'))],));
      }
    }
    
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: 
      (
        isLoading == true ?
        FullScreenLoadingWidget()
        :
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ListView(
            children:[
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  (
                    videoID != '' ?

                    Image.network('https://img.youtube.com/vi/$videoID/0.jpg')
                    :
                    Text(
                      'Enter a valid Youtube URL',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    )

                  ),
                  (  
                    title != '' ? 
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: Card(
                            elevation: 4.0,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      :
                      Container()
                  ),
                  LinearProgressIndicator(value: progress.toDouble() / 100),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
                    child: TextFormField(
                      initialValue: videoUrl,
                      onChanged: (value) {
                        setState(() {
                          videoUrl = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Enter YouTube Video URL',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue, width: 2.0),
                          borderRadius: BorderRadius.circular(10.0),
                        )
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 8.0),
                    child: Text('Save at: $downloadDirectory'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (videoUrl.isNotEmpty) {
                        viewVideoManifest();
                        viewChoices();
                      } else {
                        // Show an error message or handle empty input.
                      }
                    },
                    child: Text('View Manifest'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (videoUrl.isNotEmpty) {
                        downloadVideo();
                      } else {
                        // Show an error message or handle empty input.
                      }
                    },
                    child: Text('Download Video'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (videoUrl.isNotEmpty) {
                        downloadAudio();
                      } else {
                        // Show an error message or handle empty input.
                      }
                    },
                    child: Text('Download Audio'),
                  ),
                  Text(progress.toDouble().toString()),
                  Card(
                    elevation: 4.0,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            description,
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),              
            ]
          ),
        )
      )
    );
  }
}


class FullScreenLoadingWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // Semi-transparent black background
      child: Center(
        child: CircularProgressIndicator(), // Loading indicator
      ),
    );
  }
}

