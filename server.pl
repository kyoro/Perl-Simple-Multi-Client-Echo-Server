#!/usr/bin/perl
use strict;
use warnings;
use AnyEvent::Socket;
use AnyEvent::Handle;
use Data::Dumper;

my $cv = AE::cv;
my $count = 0;
my %connection_pool;

tcp_server(undef, 3535, sub {
    my ($fh,$host,$port) = @_;
    my $hdl;
    warn "connection open $host:$port\n";
    $hdl = AnyEvent::Handle->new(
        fh => $fh,
        on_read => sub {
            $count++;
            my $str = delete($hdl->{rbuf});
            $str =~ s/\r//;
            $str =~ s/\n//;
            if($str eq 'exit'){
                warn "connection close : ".$hdl->{_connection_id}."\n";
                delete($connection_pool{$hdl->{_connection_id}});
                $hdl->destroy;
                undef($hdl);
                warn "available connections : ".keys(%connection_pool)."\n";
            }
            foreach my $key (keys %connection_pool){
                my $h = $connection_pool{$key};
                $h->push_write(sprintf("%06d",$count).':'.$str."\n");
            }
        },
        on_eof => sub {
            delete($connection_pool{$hdl->{_connection_id}});
            $hdl->destroy;
            undef($hdl);
        },
        on_error => sub {
            delete($connection_pool{$hdl->{_connection_id}});
            $hdl->destroy;
            undef($hdl);
        }
    );
    my $connection_id = $host.':'.$port;
    $hdl->{_connection_id} = $connection_id;
    $connection_pool{$connection_id} = $hdl;
    warn "available connections : ".keys(%connection_pool)."\n";
});

$cv->recv;
