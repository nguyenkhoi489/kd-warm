<?php
require __DIR__ . '/vendor/autoload.php';

use Symfony\Component\VarDumper\Cloner\VarCloner;
use Symfony\Component\VarDumper\Dumper\CliDumper;
use Symfony\Component\VarDumper\Dumper\ServerDumper;
use Symfony\Component\VarDumper\VarDumper;

$cloner = new VarCloner();
$fallbackDumper = new CliDumper();
$server = new ServerDumper('tcp://127.0.0.1:9912', $fallbackDumper, [
    'request' => [
        'uri' => '/test',
        'method' => 'CLI',
    ],
]);

VarDumper::setHandler(function ($var) use ($cloner, $server) {
    $server->dump($cloner->cloneVar($var));
});

dump("hello world");
dump(42);
dump(true);
dump(null);
dump(3.14);
dump(['key' => 'value', 'nested' => [1, 2, 3]]);

class SampleObject {
    public string $name = 'test';
    public int $count = 99;
    private string $secret = 'hidden';
}

dump(new SampleObject());
